import json
import sys

for line in sys.stdin:
    event = json.loads(line)
    reference = event.get("objectRef", {})
    if event.get("stage") != "ResponseComplete" or reference.get("resource") != "secrets":
        continue
    print(
        event["auditID"],
        event["user"]["username"],
        event.get("impersonatedUser", {}).get("username", "-"),
        event["verb"],
        reference.get("name", "-"),
        event.get("responseStatus", {}).get("code", "-"),
    )
