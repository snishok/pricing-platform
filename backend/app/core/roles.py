from __future__ import annotations

from enum import StrEnum


class UserRole(StrEnum):
    viewer = "viewer"
    editor = "editor"
    uploader = "uploader"
    admin = "admin"


EDIT_ROLES: set[UserRole] = {UserRole.editor, UserRole.admin}
UPLOAD_ROLES: set[UserRole] = {UserRole.uploader, UserRole.admin}

