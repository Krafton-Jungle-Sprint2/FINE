// src/middleware/auth.js - 인증 미들웨어 강화 (설정 호환성 개선)
const jwt = require("jsonwebtoken");
const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();

// 설정 호환성을 위한 함수
const getJWTSecret = () => {
  // config 객체를 사용하려면 먼저 import해야 하지만,
  // 호환성을 위해 환경변수를 직접 사용하는 방식도 지원
  try {
    const { config } = require("../config/env");
    return {
      accessSecret:
        config?.jwt?.secret ||
        process.env.ACCESS_TOKEN_SECRET ||
        process.env.JWT_SECRET,
      refreshSecret:
        config?.jwt?.refreshSecret || process.env.REFRESH_TOKEN_SECRET,
      accessExpiry: config?.jwt?.accessTokenExpiry || "15m",
      refreshExpiry: config?.jwt?.refreshTokenExpiry || "7d",
    };
  } catch (error) {
    console.log("config/env 파일을 찾을 수 없음, 환경변수 직접 사용");
    return {
      accessSecret: process.env.ACCESS_TOKEN_SECRET || process.env.JWT_SECRET,
      refreshSecret: process.env.REFRESH_TOKEN_SECRET,
      accessExpiry: "15m",
      refreshExpiry: "7d",
    };
  }
};

/**
 * 액세스 토큰과 리프레시 토큰을 생성합니다.
 * 환경 변수 검증 후 안전하게 토큰을 생성합니다.
 */
const generateTokens = (userId, email, role) => {
  try {
    console.log("토큰 생성 함수 호출됨:", { userId, email, role });

    const jwtConfig = getJWTSecret();
    console.log("JWT 설정 확인:", {
      hasAccessSecret: !!jwtConfig.accessSecret,
      hasRefreshSecret: !!jwtConfig.refreshSecret,
      accessExpiry: jwtConfig.accessExpiry,
      refreshExpiry: jwtConfig.refreshExpiry,
    });

    // 환경 변수 검증
    if (!jwtConfig.accessSecret || !jwtConfig.refreshSecret) {
      const missingSecrets = [];
      if (!jwtConfig.accessSecret) missingSecrets.push("ACCESS_TOKEN_SECRET");
      if (!jwtConfig.refreshSecret) missingSecrets.push("REFRESH_TOKEN_SECRET");

      throw new Error(
        `JWT 시크릿 키가 설정되지 않았습니다: ${missingSecrets.join(", ")}`
      );
    }

    const currentTime = Math.floor(Date.now() / 1000);

    console.log("액세스 토큰 생성 시작...");
    // 액세스 토큰 생성
    const accessToken = jwt.sign(
      {
        userId,
        email,
        role,
        type: "access",
        iat: currentTime,
      },
      jwtConfig.accessSecret,
      {
        expiresIn: jwtConfig.accessExpiry,
        algorithm: "HS256",
      }
    );

    console.log("리프레시 토큰 생성 시작...");
    // 리프레시 토큰 생성
    const refreshToken = jwt.sign(
      {
        userId,
        email,
        role,
        type: "refresh",
        iat: currentTime,
      },
      jwtConfig.refreshSecret,
      {
        expiresIn: jwtConfig.refreshExpiry,
        algorithm: "HS256",
      }
    );

    console.log("토큰 생성 완료:", {
      accessTokenLength: accessToken?.length,
      refreshTokenLength: refreshToken?.length,
    });

    return { accessToken, refreshToken };
  } catch (error) {
    console.error("=== 토큰 생성 오류 상세 ===");
    console.error("오류 타입:", error.constructor.name);
    console.error("오류 메시지:", error.message);
    console.error("오류 스택:", error.stack);
    console.error("입력 파라미터:", { userId, email, role });

    throw new Error(`토큰 생성 실패: ${error.message}`);
  }
};

/**
 * JWT 인증 미들웨어
 * 토큰 만료 오류를 명확하게 구분하여 처리하도록 개선했습니다.
 */
const authenticateToken = (req, res, next) => {
  try {
    console.log("=== 토큰 인증 미들웨어 시작 ===");

    const authHeader = req.headers["authorization"];
    console.log("Authorization 헤더:", authHeader ? "존재함" : "없음");

    if (!authHeader) {
      return res.status(401).json({
        error: "인증 토큰이 필요합니다",
        code: "MISSING_TOKEN",
      });
    }

    const token = authHeader.split(" ")[1];

    if (!token) {
      return res.status(401).json({
        error: "토큰 형식이 올바르지 않습니다",
        code: "INVALID_TOKEN_FORMAT",
      });
    }

    console.log("토큰 길이:", token.length);

    const jwtConfig = getJWTSecret();

    // JWT 시크릿 검증
    if (!jwtConfig.accessSecret) {
      console.error("ACCESS_TOKEN_SECRET이 설정되지 않았습니다.");
      return res.status(500).json({
        error: "서버 설정 오류",
        code: "SERVER_CONFIG_ERROR",
      });
    }

    console.log("JWT 검증 시작...");

    // 액세스 토큰은 ACCESS_TOKEN_SECRET으로 검증합니다.
    jwt.verify(token, jwtConfig.accessSecret, (err, user) => {
      if (err) {
        console.log("JWT 검증 실패:", err.message);

        if (err instanceof jwt.TokenExpiredError) {
          return res.status(401).json({
            error: "토큰이 만료되었습니다",
            code: "TOKEN_EXPIRED",
          });
        }

        if (err instanceof jwt.JsonWebTokenError) {
          return res.status(403).json({
            error: "유효하지 않은 토큰입니다",
            code: "INVALID_TOKEN",
          });
        }

        return res.status(403).json({
          error: "토큰 검증 실패",
          code: "TOKEN_VERIFICATION_FAILED",
        });
      }

      console.log("JWT 검증 성공:", { userId: user.userId, email: user.email });

      // 토큰 타입 검증 (선택적)
      if (user.type && user.type !== "access") {
        return res.status(403).json({
          error: "잘못된 토큰 타입입니다",
          code: "INVALID_TOKEN_TYPE",
        });
      }

      req.user = user;
      next();
    });
  } catch (error) {
    console.error("=== 인증 미들웨어 오류 ===");
    console.error("오류:", error);
    return res.status(500).json({
      error: "인증 처리 중 오류가 발생했습니다",
      code: "AUTHENTICATION_ERROR",
      detail:
        process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

// 워크스페이스 멤버 확인 미들웨어
const checkWorkspaceMember = async (req, res, next) => {
  try {
    console.log("=== 워크스페이스 멤버 확인 시작 ===");

    const { wsId } = req.params;
    const userId = req.user.userId;

    console.log("워크스페이스 ID:", wsId, "사용자 ID:", userId);

    if (!wsId) {
      return res.status(400).json({
        error: "워크스페이스 ID가 필요합니다",
        code: "MISSING_WORKSPACE_ID",
      });
    }

    // 소유자 확인
    console.log("워크스페이스 소유자 확인 중...");
    const workspace = await prisma.workspace.findFirst({
      where: { id: wsId, ownerId: userId },
    });

    if (workspace) {
      console.log("워크스페이스 소유자임");
      req.isOwner = true;
      return next();
    }

    // 멤버 확인
    console.log("워크스페이스 멤버 확인 중...");
    const member = await prisma.workspaceMember.findFirst({
      where: {
        workspaceId: wsId,
        userId: userId,
        accepted: true,
      },
    });

    if (!member) {
      console.log("워크스페이스 접근 권한 없음");
      return res.status(403).json({
        error: "워크스페이스에 접근 권한이 없습니다",
        code: "ACCESS_DENIED",
      });
    }

    console.log("워크스페이스 멤버임");
    req.isOwner = false;
    next();
  } catch (error) {
    console.error("=== 워크스페이스 멤버 확인 오류 ===");
    console.error("오류:", error);

    // Prisma 관련 에러 처리
    if (error.code === "P2025") {
      return res.status(404).json({
        error: "워크스페이스를 찾을 수 없습니다",
        code: "WORKSPACE_NOT_FOUND",
      });
    }

    res.status(500).json({
      error: "서버 오류가 발생했습니다",
      code: "SERVER_ERROR",
      detail:
        process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

// 워크스페이스 소유자 확인 미들웨어
const checkWorkspaceOwner = async (req, res, next) => {
  try {
    console.log("=== 워크스페이스 소유자 확인 시작 ===");

    const { wsId } = req.params;
    const userId = req.user.userId;

    console.log("워크스페이스 ID:", wsId, "사용자 ID:", userId);

    if (!wsId) {
      return res.status(400).json({
        error: "워크스페이스 ID가 필요합니다",
        code: "MISSING_WORKSPACE_ID",
      });
    }

    const workspace = await prisma.workspace.findFirst({
      where: { id: wsId, ownerId: userId },
    });

    if (!workspace) {
      console.log("워크스페이스 소유자 권한 없음");
      return res.status(403).json({
        error: "워크스페이스 소유자만 접근할 수 있습니다",
        code: "OWNER_ACCESS_REQUIRED",
      });
    }

    console.log("워크스페이스 소유자 확인 완료");
    next();
  } catch (error) {
    console.error("=== 워크스페이스 소유자 확인 오류 ===");
    console.error("오류:", error);

    // Prisma 관련 에러 처리
    if (error.code === "P2025") {
      return res.status(404).json({
        error: "워크스페이스를 찾을 수 없습니다",
        code: "WORKSPACE_NOT_FOUND",
      });
    }

    res.status(500).json({
      error: "서버 오류가 발생했습니다",
      code: "SERVER_ERROR",
      detail:
        process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

module.exports = {
  generateTokens,
  authenticateToken,
  checkWorkspaceMember,
  checkWorkspaceOwner,
};
