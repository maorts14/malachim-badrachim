
import {UserCircle,} from "lucide-react";
import "./ChatAvatar.css";

type ChatAvatarItem = {
  avatarType?: string;
  title: string;
  dotType?: string;
  dotColor?: string;
};




// ── Chat Avatar ────────────────────────────────────────────────────────
function ChatAvatar({ item }: { item: ChatAvatarItem }) {
  const isSystem = item.avatarType === "list";

  return (
    <div className="chat-avatar-wrapper">
      <div className={`chat-avatar ${isSystem ? "system" : ""}`}>
        {isSystem ? (
          <UserCircle size={20} />
        ) : (
          item.title.slice(0, 1).toUpperCase()
        )}
      </div>

      {item.dotType === "single" && item.dotColor && (
        <div
          className="chat-avatar-dot"
          style={{ background: item.dotColor }}
        />
      )}
    </div>
  );
}
export default ChatAvatar;
