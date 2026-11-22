import json
import sys

for line in sys.stdin:
    event = json.loads(line)
    reference = event.get("objectRef", {})
    if reference.get("resource") != "pods" or not reference.get("subresource"):
        continue
    print(
        event["stage"],
        event["level"],
        event["user"]["username"],
        event["verb"],
        reference["subresource"],
        reference.get("name", "-"),
        event["requestURI"],
    )
