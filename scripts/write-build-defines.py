#!/usr/bin/env python3
"""Write private Flutter build settings without printing credentials."""
import argparse
import json
import os
from pathlib import Path


def build_defines(env):
    values = {}
    for name in ("DANDANAPI_APPID", "DANDANAPI_KEY"):
        value = env.get(name, "").strip()
        if not value or "\n" in value or "\r" in value:
            raise ValueError("弹幕授权未配置完整或格式有误，请检查 GitHub Secrets：" + name)
        values[name] = value
    values["KAZUMIT_UPDATE_URL"] = env.get("KAZUMIT_UPDATE_URL", "")
    return values


def write_defines(env, output):
    values = build_defines(env)
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        os.fchmod(handle.fileno(), 0o600)
        json.dump(values, handle, ensure_ascii=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="build/defines.json")
    args = parser.parse_args()
    try:
        write_defines(os.environ, args.output)
    except ValueError as error:
        raise SystemExit(str(error)) from None
    print("已生成私有编译配置；弹幕授权已注入。")


if __name__ == "__main__":
    main()
