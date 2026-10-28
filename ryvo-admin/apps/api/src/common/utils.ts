import { ApiResponse, PaginationMeta } from '@ryvo/shared';

export function successResponse<T>(data: T, message?: string, meta?: PaginationMeta): ApiResponse<T> {
  return { success: true, data, message, meta };
}

export function paginateMeta(page: number, limit: number, total: number): PaginationMeta {
  return {
    page,
    limit,
    total,
    totalPages: Math.ceil(total / limit) || 0,
  };
}

export function parsePagination(query: { page?: number; limit?: number }) {
  const page = Math.max(1, Number(query.page) || 1);
  const limit = Math.min(100, Math.max(1, Number(query.limit) || 20));
  const skip = (page - 1) * limit;
  return { page, limit, skip };
}

export function generateJobNumber(): string {
  const date = new Date();
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  const rand = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
  return `RYVO-${y}${m}${d}-${rand}`;
}

export function generateTicketNumber(): string {
  const rand = Math.floor(Math.random() * 100000).toString().padStart(5, '0');
  return `TKT-${rand}`;
}

export function hashToken(token: string): string {
  const crypto = require('crypto');
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function generateOtp(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/** Strip spaces/dashes and ensure E.164-style leading +. */
export function normalizePhone(phone: string): string {
  const trimmed = phone.trim();
  const digits = trimmed.replace(/[^\d+]/g, '');
  if (!digits) return trimmed;
  return digits.startsWith('+') ? digits : `+${digits}`;
}
