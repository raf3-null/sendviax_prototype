"""Reserved entry point for the durable-storage cleanup service.

Current relay cleanup runs inside app.py and shares that process's RAM.
Never import app.cleanup here: it would operate on a different, empty store.
The standalone service stays disabled until the storage contract is approved.
"""
import sys

if __name__ == "__main__":
    print("Cleanup storage adapter is not configured. Current RAM cleanup runs in the API process.", file=sys.stderr)
    sys.exit(78)
