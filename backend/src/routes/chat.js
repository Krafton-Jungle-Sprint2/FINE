// src/routes/chat.js
const express = require("express");
const { prisma } = require("../config/database");
const { authenticateToken } = require("../middleware/auth");

const router = express.Router();

// 공통: 페이지네이션 파싱
const parsePaging = (q) => {
  const pageNum = Math.max(1, parseInt(q.page ?? "1", 10) || 1);
  const limitNum = Math.min(100, Math.max(1, parseInt(q.limit ?? "50", 10) || 50));
  const offset = (pageNum - 1) * limitNum;
  return { pageNum, limitNum, offset };
};

// 워크스페이스 채팅 메시지 조회
router.get("/workspace/:workspaceId", authenticateToken, async (req, res) => {
  try {
    const { workspaceId } = req.params;
    const { pageNum, limitNum, offset } = parsePaging(req.query);

    // 멤버 확인
    const member = await prisma.workspaceMember.findFirst({
      where: { workspaceId, userId: req.user.id, accepted: true },
      select: { id: true },
    });
    if (!member) return res.status(403).json({ error: "워크스페이스에 접근할 권한이 없습니다." });

    const [messages, totalCount] = await Promise.all([
      prisma.chatMessage.findMany({
        where: { workspaceId },
        include: { user: { select: { id: true, nickname: true, avatar: true } } },
        orderBy: { createdAt: "desc" },
        take: limitNum,
        skip: offset,
      }),
      prisma.chatMessage.count({ where: { workspaceId } }),
    ]);

    res.json({
      messages: messages.reverse(),
      pagination: {
        currentPage: pageNum,
        totalPages: Math.ceil(totalCount / limitNum),
        totalCount,
        hasNext: offset + messages.length < totalCount,
        hasPrev: pageNum > 1,
      },
    });
  } catch (error) {
    console.error("채팅 메시지 조회 오류:", error);
    res.status(500).json({ error: "채팅 메시지를 조회할 수 없습니다." });
  }
});

// 워크스페이스에 채팅 메시지 전송
router.post("/workspace/:workspaceId", authenticateToken, async (req, res) => {
  try {
    const { workspaceId } = req.params;
    const content = (req.body?.content ?? "").trim();
    if (!content) return res.status(400).json({ error: "메시지 내용을 입력해주세요." });

    const member = await prisma.workspaceMember.findFirst({
      where: { workspaceId, userId: req.user.id, accepted: true },
      select: { id: true },
    });
    if (!member) return res.status(403).json({ error: "워크스페이스에 접근할 권한이 없습니다." });

    const message = await prisma.chatMessage.create({
      data: { workspaceId, userId: req.user.id, content },
      include: { user: { select: { id: true, nickname: true, avatar: true } } },
    });

    // 알림 업데이트
    const [workspace, workspaceMembers] = await Promise.all([
      prisma.workspace.findUnique({ where: { id: workspaceId }, select: { ownerId: true } }),
      prisma.workspaceMember.findMany({
        where: { workspaceId, accepted: true, userId: { not: req.user.id } },
        select: { userId: true },
      }),
    ]);

    const allMembers = [...workspaceMembers];
    if (workspace?.ownerId && workspace.ownerId !== req.user.id) {
      allMembers.push({ userId: workspace.ownerId });
    }

    await Promise.all(
      allMembers.map((m) =>
        prisma.chatNotification.upsert({
          where: { userId_workspaceId: { userId: m.userId, workspaceId } },
          update: { unreadCount: { increment: 1 } },
          create: { userId: m.userId, workspaceId, unreadCount: 1 },
        })
      )
    );

    res.status(201).json(message);
  } catch (error) {
    console.error("채팅 메시지 전송 오류:", error);
    res.status(500).json({ error: "채팅 메시지를 전송할 수 없습니다." });
  }
});

// 특정 채팅 메시지 삭제 (작성자/소유자/멤버)
router.delete("/message/:messageId", authenticateToken, async (req, res) => {
  try {
    const { messageId } = req.params;

    const message = await prisma.chatMessage.findUnique({
      where: { id: messageId },
      include: {
        workspace: {
          include: {
            members: { where: { userId: req.user.id, accepted: true }, select: { id: true } },
          },
        },
      },
    });
    if (!message) return res.status(404).json({ error: "메시지를 찾을 수 없습니다." });

    const isOwner = message.workspace.ownerId === req.user.id;
    const isAuthor = message.userId === req.user.id;
    const isMember = message.workspace.members.length > 0;
    if (!isOwner && !isAuthor && !isMember) {
      return res.status(403).json({ error: "메시지를 삭제할 권한이 없습니다." });
    }

    await prisma.chatMessage.delete({ where: { id: messageId } });

    // 알림 재계산
    const workspaceMembers = await prisma.workspaceMember.findMany({
      where: { workspaceId: message.workspaceId, accepted: true },
      select: { userId: true },
    });
    const allMembers = [
      ...workspaceMembers,
      { userId: message.workspace.ownerId },
    ];

    await Promise.all(
      allMembers.map(async (m) => {
        const notification = await prisma.chatNotification.findUnique({
          where: { userId_workspaceId: { userId: m.userId, workspaceId: message.workspaceId } },
        });
        if (!notification) return;
        const unreadCount = await prisma.chatMessage.count({
          where: { workspaceId: message.workspaceId, createdAt: { gt: notification.lastReadAt } },
        });
        await prisma.chatNotification.update({
          where: { userId_workspaceId: { userId: m.userId, workspaceId: message.workspaceId } },
          data: { unreadCount },
        });
      })
    );

    res.json({ message: "메시지가 삭제되었습니다." });
  } catch (error) {
    console.error("채팅 메시지 삭제 오류:", error);
    res.status(500).json({ error: "메시지를 삭제할 수 없습니다." });
  }
});

// 워크스페이스 채팅 메시지 검색
router.get("/workspace/:workspaceId/search", authenticateToken, async (req, res) => {
  try {
    const { workspaceId } = req.params;
    const q = (req.query?.query ?? "").trim();
    if (!q) return res.status(400).json({ error: "검색어를 입력해주세요." });

    const { pageNum, limitNum, offset } = parsePaging(req.query);

    const member = await prisma.workspaceMember.findFirst({
      where: { workspaceId, userId: req.user.id, accepted: true },
      select: { id: true },
    });
    if (!member) return res.status(403).json({ error: "워크스페이스에 접근할 권한이 없습니다." });

    const [messages, totalCount] = await Promise.all([
      prisma.chatMessage.findMany({
        where: { workspaceId, content: { contains: q } },
        include: { user: { select: { id: true, nickname: true, avatar: true } } },
        orderBy: { createdAt: "desc" },
        take: limitNum,
        skip: offset,
      }),
      prisma.chatMessage.count({ where: { workspaceId, content: { contains: q } } }),
    ]);

    res.json({
      messages: messages.reverse(),
      pagination: {
        currentPage: pageNum,
        totalPages: Math.ceil(totalCount / limitNum),
        totalCount,
        hasNext: offset + messages.length < totalCount,
        hasPrev: pageNum > 1,
      },
    });
  } catch (error) {
    console.error("채팅 메시지 검색 오류:", error);
    res.status(500).json({ error: "메시지 검색에 실패했습니다." });
  }
});

// 워크스페이스 채팅 메시지 읽음 처리
router.post("/workspace/:workspaceId/read", authenticateToken, async (req, res) => {
  try {
    const { workspaceId } = req.params;
    const userId = req.user.id;

    const [member, isOwner] = await Promise.all([
      prisma.workspaceMember.findFirst({ where: { workspaceId, userId, accepted: true }, select: { id: true } }),
      prisma.workspace.findFirst({ where: { id: workspaceId, ownerId: userId }, select: { id: true } }),
    ]);
    if (!member && !isOwner) {
      return res.status(403).json({ error: "워크스페이스에 접근할 권한이 없습니다." });
    }

    await prisma.chatNotification.upsert({
      where: { userId_workspaceId: { userId, workspaceId } },
      update: { unreadCount: 0, lastReadAt: new Date() },
      create: { userId, workspaceId, unreadCount: 0, lastReadAt: new Date() },
    });

    res.json({ message: "채팅 메시지가 읽음 처리되었습니다." });
  } catch (error) {
    console.error("채팅 메시지 읽음 처리 오류:", error);
    res.status(500).json({ error: "읽음 처리에 실패했습니다." });
  }
});

// 워크스페이스별 읽지 않은 채팅 메시지 개수 조회
router.get("/workspace/:workspaceId/unread-count", authenticateToken, async (req, res) => {
  try {
    const { workspaceId } = req.params;
    const userId = req.user.id;

    const [member, isOwner] = await Promise.all([
      prisma.workspaceMember.findFirst({ where: { workspaceId, userId, accepted: true }, select: { id: true } }),
      prisma.workspace.findFirst({ where: { id: workspaceId, ownerId: userId }, select: { id: true } }),
    ]);
    if (!member && !isOwner) {
      return res.status(403).json({ error: "워크스페이스에 접근할 권한이 없습니다." });
    }

    const notification = await prisma.chatNotification.findUnique({
      where: { userId_workspaceId: { userId, workspaceId } },
      select: { unreadCount: true },
    });

    res.json({ unreadCount: notification?.unreadCount || 0 });
  } catch (error) {
    console.error("읽지 않은 메시지 개수 조회 오류:", error);
    res.status(500).json({ error: "읽지 않은 메시지 개수 조회에 실패했습니다." });
  }
});

module.exports = router;
