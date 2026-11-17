import json
import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch


BIN = Path(__file__).resolve().parents[1] / "qml/inir/defaults/widgets/ai-usage/bin"


class UsageAccountingTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.home = Path(self.scratch.name)
        self.environment = patch.dict(os.environ, {
            "HOME": str(self.home),
            "CODEX_HOME": str(self.home / "codex"),
            "CODEX_USAGE_CACHE_FILE": str(self.home / "cache/codex.json"),
            "OPENAI_API_KEY": "",
            "OPENAI_BASE_URL": "",
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def codex(self):
        return runpy.run_path(str(BIN / "codex-usage"))

    def test_codex_saved_names_follow_renames(self):
        index = self.home / "codex/session_index.jsonl"
        index.parent.mkdir()
        index.write_text('\n'.join([
            json.dumps({"id": "session", "thread_name": "First title"}),
            "not json",
            "[]",
            json.dumps({"id": "session", "thread_name": " Renamed\n title "}),
        ]))
        collector = self.codex()
        self.assertEqual(collector["session_names"](), {"session": "Renamed title"})
        with index.open("a") as handle:
            handle.write('\n' + json.dumps({"id": "session", "thread_name": "Newest"}))
        self.assertEqual(collector["session_names"](), {"session": "Newest"})

    def test_codex_quota_cache_is_bound_to_login(self):
        auth = self.home / "codex/auth.json"
        auth.parent.mkdir()
        auth.write_text("first login")
        collector = self.codex()
        context = collector["rpc_context"]()
        cache = collector["RPC_FILE"]
        cache.parent.mkdir()
        cache.write_text(json.dumps({"checked_at": collector["now_epoch"](),
                                     "context": context, "data": {"plan": "first"}}))
        self.assertEqual(collector["cached_rpc"](), ({"plan": "first"}, True))
        auth.write_text("different login")
        self.assertEqual(collector["cached_rpc"](), (None, False))
        auth.unlink()
        self.assertIsNone(collector["rpc_context"]())
        self.assertEqual(collector["cached_rpc"](), (None, False))

    def test_opencode_mirrors_do_not_hide_distinct_requests(self):
        collector = runpy.run_path(str(BIN / "opencode-usage"))
        message = dict(session_id="session", model_id="model", provider_id="provider",
                       time=1000, input=10, output=20, reasoning=0, cache_read=0,
                       cache_write=0, cost=0.1)
        first = dict(message, _message_id="one")
        second = dict(message, _message_id="two")
        mirror = dict(message, _message_id="")
        rows = collector["merge_message_stores"]([first, second], [mirror, dict(mirror)])
        self.assertEqual(len(rows), 2)
        rows = collector["merge_message_stores"]([first], [dict(second)])
        self.assertEqual(len(rows), 2)

    def test_claude_future_usage_is_not_charged(self):
        collector = runpy.run_path(str(BIN / "claude-spending.py"))
        message = dict(event_id="future", time=2000000000000, model_id="claude-sonnet-4-5",
                       input=100, output=10, cache_read=0, cache_write=0)
        summary, costs = collector["estimate_spending"]([message], state_dir=self.home / "state", now=1999999999)
        self.assertEqual(summary["invalid_events"], 1)
        self.assertEqual(costs, {})
        self.assertEqual(summary["priced_tokens"], 0)


if __name__ == "__main__":
    unittest.main()
