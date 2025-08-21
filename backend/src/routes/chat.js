const express = require("express");
const { PrismaClient } = require("@prisma/client");
const auth = require("../middleware/auth");

const router = express.Router();
const prisma = new PrismaClient();

// 워크스페이스 채팅 메시지 조회
router.get("/workspace/:workspaceId", auth, async (req, res) => {
  try {
    const { workspaceId } = req.params;
    const { page = 1, limit = 50 } = req.query;
    const offset = (page - 1) * limit;

    // 워크스페이스 멤버인지 확인
    const member = await prisma.workspaceMember.findFirst({
      where: {
        workspaceId,
        userId: req.user.id,
        accepted: true,
      },
    });

    if (!member) {
      return res
        .status(403)
        .json({ error: "워크스페이스에 접근할 권한이 없습니다." });
    }

    // 채팅 메시지 조회 (최신순)
    const messages = await prisma.chatMessage.findMany({
      where: { workspaceId },
      include: {
        user: {
          select: {
            id: true,
            nickname: true,
            avatar: true,
          },
        },
      },
      orderBy: { createdAt: "desc" },
      take: parseInt(limit),
      skip: offset,
    });

    // 전체 메시지 수 조회
    const totalCount = await prisma.chatMessage.count({
      where: { workspaceId },
    });

    res.json({
      messages: messages.reverse(), // 시간순으로 정렬
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(totalCount / limit),
        totalCount,
        hasNext: offset + messages.length < totalCount,
        hasPrev: page > 1,
      },
    });
  } catch (error) {
    console.error("채팅 메시지 조회 오류:", error);
    res.status(500).json({ error: "채팅 메시지를 조회할 수 없습니다." });
  }
});

// 워크스페이스에 채팅 메시지 전송
router.post("/workspace/:workspaceId", auth, async (req, res) => {
  try {
    const { workspaceId } = req.params;
    const { content } = req.body;

    if (!content || content.trim().length === 0) {
      return res.status(400).json({ error: "메시지 내용을 입력해주세요." });
    }

    // 워크스페이스 멤버인지 확인
    const member = await prisma.workspaceMember.findFirst({
      where: {
        workspaceId,
        userId: req.user.id,
        accepted: true,
      },
    });

    if (!member) {
      return res
        .status(403)
        .json({ error: "워크스페이스에 접근할 권한이 없습니다." });
    }

    // 채팅 메시지 생성
    const message = await prisma.chatMessage.create({
      data: {
        workspaceId,
        userId: req.user.id,
        content: content.trim(),
      },
      include: {
        user: {
          select: {
            id: true,
            nickname: true,
            avatar: true,
          },
        },
      },
    });

    res.status(201).json(message);
  } catch (error) {
    console.error("채팅 메시지 전송 오류:", error);
    res.status(500).json({ error: "채팅 메시지를 전송할 수 없습니다." });
  }
});

// 특정 채팅 메시지 삭제 (작성자만 가능)
router.delete("/message/:messageId", auth, async (req, res) => {
  try {
    const { messageId } = req.params;

    // 메시지 조회
    const message = await prisma.chatMessage.findUnique({
      where: { id: messageId },
      include: {
        workspace: {
          include: {
            members: {
              where: { userId: req.user.id, accepted: true },
            },
          },
        },
      },
    });

    if (!message) {
      return res.status(404).json({ error: "메시지를 찾을 수 없습니다." });
    }

    // 권한 확인 (작성자이거나 워크스페이스 소유자)
    const isOwner = message.workspace.ownerId === req.user.id;
    const isAuthor = message.userId === req.user.id;
    const isMember = message.workspace.members.length > 0;

    if (!isOwner && !isAuthor && !isMember) {
      return res
        .status(403)
        .json({ error: "메시지를 삭제할 권한이 없습니다." });
    }

    // 메시지 삭제
    await prisma.chatMessage.delete({
      where: { id: messageId },
    });

    res.json({ message: "메시지가 삭제되었습니다." });
  } catch (error) {
    console.error("채팅 메시지 삭제 오류:", error);
    res.status(500).json({ error: "메시지를 삭제할 수 없습니다." });
  }
});

// 워크스페이스 채팅 메시지 검색
router.get("/workspace/:workspaceId/search", auth, async (req, res) => {
  try {
    const { workspaceId } = req.params;
    const { query, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    if (!query || query.trim().length === 0) {
      return res.status(400).json({ error: "검색어를 입력해주세요." });
    }

    // 워크스페이스 멤버인지 확인
    const member = await prisma.workspaceMember.findFirst({
      where: {
        workspaceId,
        userId: req.user.id,
        accepted: true,
      },
    });

    if (!member) {
      return res
        .status(403)
        .json({ error: "워크스페이스에 접근할 권한이 없습니다." });
    }

    // 메시지 검색
    const messages = await prisma.chatMessage.findMany({
      where: {
        workspaceId,
        content: {
          contains: query.trim(),
        },
      },
      include: {
        user: {
          select: {
            id: true,
            nickname: true,
            avatar: true,
          },
        },
      },
      orderBy: { createdAt: "desc" },
      take: parseInt(limit),
      skip: offset,
    });

    // 검색 결과 수 조회
    const totalCount = await prisma.chatMessage.count({
      where: {
        workspaceId,
        content: {
          contains: query.trim(),
        },
      },
    });

    res.json({
      messages: messages.reverse(),
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(totalCount / limit),
        totalCount,
        hasNext: offset + messages.length < totalCount,
        hasPrev: page > 1,
      },
    });
  } catch (error) {
    console.error("채팅 메시지 검색 오류:", error);
    res.status(500).json({ error: "메시지 검색에 실패했습니다." });
  }
});

module.exports = router;
