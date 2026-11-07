from __future__ import annotations

import json
import re
from typing import Any


class SchemaError(ValueError):
    pass


def _resolve(document: dict[str, Any], reference: str) -> dict[str, Any]:
    if not reference.startswith("#/"):
        raise SchemaError(f"unsupported schema reference {reference!r}")
    value: Any = document
    for raw in reference[2:].split("/"):
        key = raw.replace("~1", "/").replace("~0", "~")
        if not isinstance(value, dict) or key not in value:
            raise SchemaError(f"unresolved schema reference {reference!r}")
        value = value[key]
    if not isinstance(value, dict):
        raise SchemaError(f"schema reference {reference!r} is not an object")
    return value


def _is_type(value: Any, expected: str) -> bool:
    return {
        "array": lambda: isinstance(value, list),
        "boolean": lambda: isinstance(value, bool),
        "integer": lambda: isinstance(value, int) and not isinstance(value, bool),
        "number": lambda: isinstance(value, (int, float)) and not isinstance(value, bool),
        "object": lambda: isinstance(value, dict),
        "string": lambda: isinstance(value, str),
        "null": lambda: value is None,
    }.get(expected, lambda: False)()


def validate(value: Any, schema: dict[str, Any], *, label: str, document: dict[str, Any] | None = None) -> None:
    root = document or schema
    if "$ref" in schema:
        validate(value, _resolve(root, schema["$ref"]), label=label, document=root)
        return

    expected = schema.get("type")
    if isinstance(expected, str) and not _is_type(value, expected):
        raise SchemaError(f"{label}: expected {expected}")
    if "const" in schema and value != schema["const"]:
        raise SchemaError(f"{label}: expected {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        choices = ", ".join(repr(choice) for choice in schema["enum"])
        raise SchemaError(f"{label}: expected one of {choices}")

    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0):
            raise SchemaError(f"{label}: string is too short")
        pattern = schema.get("pattern")
        if isinstance(pattern, str) and re.search(pattern, value) is None:
            raise SchemaError(f"{label}: does not match {pattern!r}")

    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            raise SchemaError(f"{label}: needs at least {schema['minItems']} entries")
        if schema.get("uniqueItems"):
            seen: set[str] = set()
            for index, item in enumerate(value):
                encoded = json.dumps(item, sort_keys=True, separators=(",", ":"))
                if encoded in seen:
                    raise SchemaError(f"{label}[{index}]: duplicate entry")
                seen.add(encoded)
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for index, item in enumerate(value):
                validate(item, item_schema, label=f"{label}[{index}]", document=root)

    if isinstance(value, dict):
        properties = schema.get("properties", {})
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                raise SchemaError(f"{label}.{key}: missing required field")
        if schema.get("additionalProperties") is False:
            unknown = sorted(set(value) - set(properties))
            if unknown:
                raise SchemaError(f"{label}.{unknown[0]}: unknown field")
        for key, child in value.items():
            child_schema = properties.get(key)
            if isinstance(child_schema, dict):
                validate(child, child_schema, label=f"{label}.{key}", document=root)
