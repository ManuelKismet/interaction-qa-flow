class DomainError(Exception):
    """Base exception for expected domain failures."""


class ConflictError(DomainError):
    pass


class NotFoundError(DomainError):
    pass


class PermissionDeniedError(DomainError):
    pass


class ServiceUnavailableError(DomainError):
    pass