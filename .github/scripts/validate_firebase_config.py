#!/usr/bin/env python3
"""Validate Firebase google-services.json structure and OAuth client configuration."""
import json
import re
import sys

PATH = "android/app/google-services.json"


def fail(msg):
    print(f"::error::{msg}")
    sys.exit(1)


def main():
    try:
        with open(PATH) as f:
            data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        fail(f"Cannot read or parse {PATH}: {e}")

    # --- Project info ---
    project = data.get("project_info", {})
    project_id = project.get("project_id")
    if not project_id:
        fail("Missing project_info.project_id")
    print(f"Project ID: {project_id}")

    # --- Client ---
    clients = data.get("client", [])
    if not clients:
        fail("No clients in google-services.json")
    if len(clients) != 1:
        fail(f"Expected exactly 1 client, found {len(clients)}")

    client = clients[0]
    android_info = client.get("client_info", {}).get("android_client_info", {})
    package_name = android_info.get("package_name")
    if not package_name:
        fail("Missing android_client_info.package_name")
    print(f"Package name: {package_name}")

    # --- OAuth clients ---
    # Android OAuth clients are in oauth_client array (type 1)
    oauth_clients = client.get("oauth_client", [])
    if not oauth_clients:
        fail("No OAuth clients found in oauth_client array")

    android_clients = [c for c in oauth_clients if c.get("client_type") == 1]

    # Google Services Gradle plugin reads default_web_client_id from oauth_client (type 3).
    # appinvite_service.other_platform_oauth_client is not a substitute for this entry.
    web_clients = [c for c in oauth_clients if c.get("client_type") == 3]

    if not android_clients:
        fail("No Android OAuth client (type 1) found in oauth_client")
    if not web_clients:
        fail("No Web OAuth client (type 3) found in services.appinvite_service.other_platform_oauth_client")

    # Check duplicates within the authoritative oauth_client list only.
    # Firebase normally repeats the Web client under appinvite_service, so
    # comparing those two arrays would incorrectly reject a valid config.
    oauth_ids = [c.get("client_id") for c in oauth_clients]
    if len(oauth_ids) != len(set(oauth_ids)):
        fail("Duplicate client IDs found in oauth_client")

    # Validate Web client ID format
    for wc in web_clients:
        cid = wc.get("client_id", "")
        if not re.match(r"^[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$", cid):
            fail(f"Invalid Web OAuth client ID format: {cid}")

    # Validate certificate hashes are SHA-1 (40 hex chars) or SHA-256 (64 hex chars)
    for ac in android_clients:
        cert = ac.get("android_info", {}).get("certificate_hash", "")
        if cert:
            if len(cert) == 40:
                print(f"  Android OAuth client: SHA-1 certificate hash found ({cert[:8]}...)")
            elif len(cert) == 64:
                print(f"  Android OAuth client: SHA-256 certificate hash found ({cert[:8]}...)")
            else:
                fail(f"Invalid certificate hash length: {len(cert)} (expected 40 for SHA-1 or 64 for SHA-256)")

    print(f"Android OAuth clients (type 1 in oauth_client): {len(android_clients)}")
    print(f"Web OAuth clients (type 3 in appinvite_service): {len(web_clients)}")
    print("Firebase configuration validation: PASS")


if __name__ == "__main__":
    main()
