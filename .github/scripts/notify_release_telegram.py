#!/usr/bin/env python3

import json
import os
import sys
import urllib.error
import urllib.request


def main() -> None:
    token = os.environ["TELEGRAM_BOT_TOKEN"]
    chat_id = os.environ["TELEGRAM_CHAT_ID"]
    tag = os.environ.get("RELEASE_TAG") or ""
    name = os.environ.get("RELEASE_NAME") or (f"Новый релиз {tag}" if tag else "Новый релиз")
    body = (os.environ.get("RELEASE_BODY") or "").strip()
    release_url = os.environ.get("RELEASE_URL") or ""
    game_url = os.environ.get("GAME_URL") or "https://occultnerdbird.github.io/sych-game/"

    if not body:
        body = "Без описания изменений."

    parts = [f"🎉 {name}", "", body]

    if release_url:
        parts.extend(["", f"Подробнее: {release_url}"])

    parts.extend(["", f"Играть: {game_url}"])
    text = "\n".join(parts)

    payload = json.dumps({"chat_id": chat_id, "text": text}).encode("utf-8")
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    request = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})

    try:
        with urllib.request.urlopen(request) as response:
            sys.stdout.write(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        sys.stderr.write(exc.read().decode("utf-8"))
        raise


if __name__ == "__main__":
    main()

