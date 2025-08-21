-- CreateTable
CREATE TABLE `workspace_settings` (
    `id` VARCHAR(191) NOT NULL,
    `workspaceId` VARCHAR(191) NOT NULL,
    `theme` VARCHAR(191) NOT NULL DEFAULT 'light',
    `notifications` JSON NOT NULL DEFAULT '{"email": true, "push": true, "chat": true}',
    `privacy` VARCHAR(191) NOT NULL DEFAULT 'private',
    `allowInvites` BOOLEAN NOT NULL DEFAULT true,
    `maxMembers` INTEGER NOT NULL DEFAULT 100,
    `customFields` JSON NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    UNIQUE INDEX `workspace_settings_workspaceId_key`(`workspaceId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `workspace_settings` ADD CONSTRAINT `workspace_settings_workspaceId_fkey` FOREIGN KEY (`workspaceId`) REFERENCES `workspaces`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
