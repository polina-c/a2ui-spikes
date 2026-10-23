import {useState, type ComponentProps} from 'react';
import ReactMarkdown, {type Components} from 'react-markdown';
import remarkGfm from 'remark-gfm';
import './markdown.css';

/** GitHub's additions to Markdown, such as tables, which models often use. */
const remarkPlugins = [remarkGfm];

const components: Components = {
  // A new tab, so that following a link does not close the chat.
  a: ({href, children}) => (
    <a href={href} target="_blank" rel="noreferrer">
      {children}
    </a>
  ),
  img: MarkdownImage,
};

/**
 * Renders `text` as Markdown, like `MarkdownBody` from Flutter's
 * flutter_markdown_plus.
 *
 * HTML in `text` is shown as text, not rendered.
 */
export function Markdown({text}: {text: string}) {
  return (
    <div className="markdown">
      <ReactMarkdown remarkPlugins={remarkPlugins} components={components}>
        {text}
      </ReactMarkdown>
    </div>
  );
}

/**
 * A picture, such as the photo of a recommended product.
 *
 * Replaced by its alt text when it cannot be loaded.
 */
function MarkdownImage({src, alt}: ComponentProps<'img'>) {
  const [failed, setFailed] = useState(false);
  if (failed) return <span>{alt}</span>;
  return <img src={src} alt={alt} onError={() => setFailed(true)} />;
}
