import { hrefFor, isLink, linkParts, parseLegalContent } from '@/lib/legal-content';

function LinkedText({
  text,
  className,
  linkClassName,
}: {
  text: string;
  className: string;
  linkClassName: string;
}) {
  return (
    <p className={className}>
      {linkParts(text).map((part, index) =>
        isLink(part) ? (
          <a key={`${part}-${index}`} href={hrefFor(part)} className={linkClassName}>
            {part}
          </a>
        ) : (
          <span key={`${part}-${index}`}>{part}</span>
        ),
      )}
    </p>
  );
}

export function LegalDocumentBody({
  content,
  variant,
}: {
  content: string;
  variant: 'landing' | 'admin';
}) {
  const blocks = parseLegalContent(content);
  const heading =
    variant === 'landing' ? 'landing-text-navy text-2xl' : 'text-base font-semibold text-primary';
  const paragraph =
    variant === 'landing'
      ? 'landing-text-muted mt-4 text-base leading-relaxed'
      : 'mt-3 text-sm leading-relaxed text-secondary';
  const linkClassName =
    variant === 'landing'
      ? 'font-medium text-[var(--landing-orange)] hover:underline'
      : 'font-medium text-accent hover:underline';

  return (
    <>
      {blocks.map((block, index) => {
        if (block.type === 'heading') {
          return (
            <h2 key={`h-${index}`} className={`${heading} ${index === 0 ? 'mt-0' : variant === 'landing' ? 'mt-10 sm:mt-12' : 'mt-8'}`}>
              {block.text}
            </h2>
          );
        }
        if (block.type === 'list') {
          return (
            <ul
              key={`l-${index}`}
              className={
                variant === 'landing'
                  ? undefined
                  : 'mt-3 list-disc space-y-1.5 pl-5 text-sm leading-relaxed text-secondary'
              }
            >
              {block.items.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          );
        }
        return (
          <LinkedText key={`p-${index}`} text={block.text} className={paragraph} linkClassName={linkClassName} />
        );
      })}
    </>
  );
}
