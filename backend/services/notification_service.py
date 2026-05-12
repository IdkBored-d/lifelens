"""
FCM push notification service using firebase-admin.
Reads sphere member FCM tokens from Firestore and sends
a notification to all members except the sender.
"""
from __future__ import annotations

import json
import logging
import os
from typing import List, Optional

logger = logging.getLogger(__name__)

_firebase_app = None


def _get_firebase_app():
    """Lazy-initialise the firebase-admin app using the service account JSON
    stored in the FIREBASE_SERVICE_ACCOUNT_JSON environment variable."""
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app

    try:
        import firebase_admin
        from firebase_admin import credentials

        sa_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "")
        if not sa_json:
            logger.warning("[FCM] FIREBASE_SERVICE_ACCOUNT_JSON not set — notifications disabled.")
            return None

        sa_dict = json.loads(sa_json)
        cred = credentials.Certificate(sa_dict)

        if not firebase_admin._apps:
            _firebase_app = firebase_admin.initialize_app(cred)
        else:
            _firebase_app = firebase_admin.get_app()

        logger.info("[FCM] firebase-admin initialised.")
        return _firebase_app

    except Exception as e:
        logger.error(f"[FCM] Failed to initialise firebase-admin: {e}")
        return None


async def send_sphere_message_notification(
    *,
    sphere_id: str,
    sphere_name: str,
    sender_user_id: str,
    sender_nickname: str,
    text: str,
) -> None:
    """
    Reads FCM tokens for all sphere members (excluding the sender) from
    Firestore and sends a push notification to each one.
    """
    app = _get_firebase_app()
    if app is None:
        return  # firebase-admin not configured — skip silently

    try:
        from firebase_admin import firestore as admin_firestore, messaging

        db = admin_firestore.client()

        # Read all member docs in the sphere.
        members_ref = (
            db.collection("spheres")
            .document(sphere_id)
            .collection("members")
        )
        member_docs = members_ref.stream()

        # Collect user IDs of all members except the sender.
        other_user_ids: List[str] = [
            doc.id for doc in member_docs if doc.id != sender_user_id
        ]

        if not other_user_ids:
            return

        # Read FCM tokens from each user's /users/{uid} doc.
        tokens: List[str] = []
        for uid in other_user_ids:
            user_doc = db.collection("users").document(uid).get()
            if user_doc.exists:
                token: Optional[str] = user_doc.to_dict().get("fcmToken")  # type: ignore[union-attr]
                if token:
                    tokens.append(token)

        if not tokens:
            return

        # Truncate message preview for the notification body.
        body_preview = text if len(text) <= 100 else text[:97] + "…"

        # Send a multicast message (up to 500 tokens per call).
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=sphere_name,
                body=f"{sender_nickname}: {body_preview}",
            ),
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    channel_id="sphere_messages",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        badge=1,
                    )
                )
            ),
            tokens=tokens[:500],
        )
        response = messaging.send_each_for_multicast(message)
        logger.info(
            f"[FCM] Sent to {len(tokens)} device(s) in sphere '{sphere_name}': "
            f"{response.success_count} success, {response.failure_count} failure."
        )

    except Exception as e:
        logger.error(f"[FCM] Error sending sphere notification: {e}")
