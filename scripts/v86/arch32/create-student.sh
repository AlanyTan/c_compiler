#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_ROOT="/target"
SOURCE_DIR="/v86-config/c_src"
STUDENT_USER="student"
STUDENT_PASSWORD="Student"

usage() {
  cat <<'EOF'
Usage: create-student.sh --target /path/to/rootfs [--source /path/to/src]
EOF
}

while (($#)); do
  case "$1" in
    --target)
      (($# >= 2)) || { echo "--target requires a path" >&2; exit 1; }
      TARGET_ROOT=$2
      shift 2
      ;;
    --source)
      (($# >= 2)) || { echo "--source requires a path" >&2; exit 1; }
      SOURCE_DIR=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ -d "$TARGET_ROOT" ]] || {
  echo "target root does not exist: $TARGET_ROOT" >&2
  exit 1
}

if ! chroot "$TARGET_ROOT" id -u "$STUDENT_USER" >/dev/null 2>&1; then
  chroot "$TARGET_ROOT" groupadd -f "$STUDENT_USER"
  chroot "$TARGET_ROOT" useradd \
    -m \
    -d "/home/$STUDENT_USER" \
    -s /bin/bash \
    -g "$STUDENT_USER" \
    "$STUDENT_USER"
fi

chroot "$TARGET_ROOT" install -d -o "$STUDENT_USER" -g "$STUDENT_USER" -m 0755 \
  "/home/$STUDENT_USER" \
  "/home/$STUDENT_USER/src"

printf '%s:%s\n' "$STUDENT_USER" "$STUDENT_PASSWORD" | chroot "$TARGET_ROOT" chpasswd

printf '%s:%s\n' "$STUDENT_USER" "$STUDENT_PASSWORD" | chroot "$TARGET_ROOT" chpasswd

cat >"$TARGET_ROOT/home/$STUDENT_USER/.bashrc" <<'EOF'
# ~/.bashrc for the student account.
[[ $- != *i* ]] && return

force_color_prompt=yes
case "$TERM" in
  xterm-color|vt100|*-256color) color_prompt=yes ;;
  *) color_prompt=no ;;
esac

if [ "$color_prompt" = yes ]; then
    PS1='\[\033[01;32m\][\u@\h\[\033[00m\]:\[\033[01;34m\]\W\033[01;32m\]]\[\033[00m\]\$ '
else
    PS1='\u@\h:\w\$ '
fi
unset color_prompt

PROMPT_DIRTRIM=2
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
if [ -f /etc/bash_completion ]; then . /etc/bash_completion; fi
EOF

cat >"$TARGET_ROOT/home/$STUDENT_USER/.bash_profile" <<'EOF'
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
EOF

if [[ -d "$SOURCE_DIR" ]]; then
  cp -a "$SOURCE_DIR"/. "$TARGET_ROOT/home/$STUDENT_USER/src/"
fi

chroot "$TARGET_ROOT" chown -R "$STUDENT_USER:$STUDENT_USER" "/home/$STUDENT_USER"
chmod 0755 "$TARGET_ROOT/home/$STUDENT_USER"
chmod 0755 "$TARGET_ROOT/home/$STUDENT_USER/src"

printf 'student account ready: %s\n' "$STUDENT_USER"
