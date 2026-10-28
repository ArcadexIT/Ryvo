'use client';

import { useFileAccessUrl } from '@/hooks/use-file-access-url';

interface SecureFilePreviewProps {
  fileUrl: string;
  title?: string;
  className?: string;
}

export function SecureFilePreview({ fileUrl, title = 'Document preview', className }: SecureFilePreviewProps) {
  const { data: accessUrl, isLoading, error } = useFileAccessUrl(fileUrl);

  if (isLoading) {
    return (
      <div className={`flex h-96 items-center justify-center rounded-lg border border-border bg-surface ${className ?? ''}`}>
        <p className="text-sm text-secondary">Loading preview...</p>
      </div>
    );
  }

  if (error || !accessUrl) {
    return (
      <div className={`flex h-96 items-center justify-center rounded-lg border border-border bg-surface ${className ?? ''}`}>
        <p className="text-sm text-danger">Could not load file preview</p>
      </div>
    );
  }

  const isPdf = accessUrl.toLowerCase().includes('.pdf') || fileUrl.toLowerCase().endsWith('.pdf');

  if (isPdf) {
    return (
      <iframe
        src={accessUrl}
        className={`h-96 w-full rounded-lg border border-border bg-surface ${className ?? ''}`}
        title={title}
      />
    );
  }

  return (
    <img
      src={accessUrl}
      alt={title}
      className={`max-h-96 w-full rounded-lg border border-border bg-surface object-contain ${className ?? ''}`}
    />
  );
}
