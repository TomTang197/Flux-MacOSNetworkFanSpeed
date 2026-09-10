#!/usr/bin/env python3
"""
Generate an Ed25519 keypair compatible with Sparkle 2.
"""

import base64
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization

def main():
    # Generate Ed25519 private key
    private_key = ed25519.Ed25519PrivateKey.generate()
    public_key = private_key.public_key()

    # Raw bytes
    private_bytes = private_key.private_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PrivateFormat.Raw,
        encryption_algorithm=serialization.NoEncryption()
    )
    public_bytes = public_key.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw
    )

    # Base64 encode
    private_b64 = base64.b64encode(private_bytes).decode('ascii')
    public_b64 = base64.b64encode(public_bytes).decode('ascii')

    print("=" * 60)
    print("Sparkle 2 Ed25519 Keypair Generated Successfully")
    print("=" * 60)
    print("\n[PUBLIC KEY] (Put this into AeroPulse/Info.plist as SUPublicEDKey):")
    print(public_b64)
    print("\n[PRIVATE KEY] (Put this into GitHub Repo -> Settings -> Secrets -> SPARKLE_ED_KEY):")
    print(private_b64)
    print("=" * 60)

    # Save to a local gitignored file for convenience
    with open(".sparkle_keys.env", "w") as f:
        f.write(f"SPARKLE_PUBLIC_KEY={public_b64}\n")
        f.write(f"SPARKLE_PRIVATE_KEY={private_b64}\n")
    print("Keys temporarily saved to .sparkle_keys.env (do NOT commit this file).")

if __name__ == "__main__":
    main()
