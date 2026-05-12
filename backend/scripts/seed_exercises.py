"""
Seed the Firestore exercise catalog used by the Flutter Exercise screen.

The app reads from the top-level `exercises` collection. Firestore rules allow
signed-in clients to read the catalog, but only backend/admin code can create
catalog entries. This script uses firebase-admin and is safe to rerun: existing
exercise docs keep user counters such as timesChosen and timesSearched.

Auth options:
- FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account", ...}'
- GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json

Run from the backend folder:
    python scripts/seed_exercises.py --dry-run
    python scripts/seed_exercises.py
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from datetime import UTC, datetime
from typing import Any, Iterable

import requests


Exercise = dict[str, Any]


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", value.strip().lower())
    return slug.strip("_")


def exercise(
    name: str,
    type_: str,
    muscle: str,
    difficulty: str,
    equipment: list[str],
    cues: list[str],
    benefits: list[str],
) -> Exercise:
    equipment_text = ", ".join(equipment) if equipment else "bodyweight"
    return {
        "id": slugify(name),
        "name": name,
        "type": type_,
        "muscle": muscle,
        "difficulty": difficulty,
        "description": f"A {difficulty.lower()} {type_.lower()} exercise for {muscle.lower()} using {equipment_text}.",
        "instructions": " ".join(cues),
        "equipment": equipment,
        "benefits": benefits,
        "instructionUrl": "",
        "videoUrl": "",
    }


EXERCISES: list[Exercise] = [
    exercise("Barbell Back Squat", "Strength", "Quadriceps", "Intermediate", ["Barbell", "Squat Rack"], ["Set the bar across your upper back and brace your core.", "Squat down with knees tracking over toes, then drive through the floor to stand."], ["Leg strength", "Core stability", "Power development"]),
    exercise("Barbell Front Squat", "Strength", "Quadriceps", "Advanced", ["Barbell", "Squat Rack"], ["Hold the bar in a front rack position with elbows high.", "Keep your torso tall as you squat and stand under control."], ["Quad strength", "Upper-back posture", "Core control"]),
    exercise("Goblet Squat", "Strength", "Quadriceps", "Beginner", ["Dumbbell", "Kettlebell"], ["Hold one weight at chest height.", "Sit between your hips, pause, then stand tall."], ["Squat pattern", "Leg strength", "Beginner-friendly loading"]),
    exercise("Leg Press", "Strength", "Quadriceps", "Beginner", ["Leg Press Machine"], ["Set feet shoulder-width on the platform.", "Lower with control, then press without locking knees hard."], ["Leg strength", "Stable setup", "Controlled volume"]),
    exercise("Hack Squat", "Strength", "Quadriceps", "Intermediate", ["Hack Squat Machine"], ["Set shoulders under pads and brace.", "Lower until comfortable depth, then press through mid-foot."], ["Quad focus", "Machine stability", "Lower-body strength"]),
    exercise("Bulgarian Split Squat", "Strength", "Glutes", "Intermediate", ["Dumbbells", "Bench"], ["Place rear foot on a bench and square your hips.", "Lower straight down, then drive through the front foot."], ["Single-leg strength", "Balance", "Glute strength"]),
    exercise("Walking Lunge", "Strength", "Legs", "Beginner", ["Bodyweight", "Dumbbells"], ["Step forward into a lunge with control.", "Push through the front foot and bring the back leg through."], ["Leg endurance", "Coordination", "Hip stability"]),
    exercise("Reverse Lunge", "Strength", "Glutes", "Beginner", ["Bodyweight", "Dumbbells"], ["Step one foot backward and lower under control.", "Drive through the front foot to return to standing."], ["Knee-friendly leg work", "Glute strength", "Balance"]),
    exercise("Step-Up", "Strength", "Legs", "Beginner", ["Box", "Bench", "Dumbbells"], ["Place one foot fully on a box or bench.", "Stand by driving through the elevated foot, then lower slowly."], ["Single-leg strength", "Hip stability", "Functional movement"]),
    exercise("Barbell Hip Thrust", "Strength", "Glutes", "Intermediate", ["Barbell", "Bench"], ["Set upper back against a bench with bar over hips.", "Drive hips upward, pause, then lower with control."], ["Glute strength", "Hip extension", "Posterior-chain power"]),
    exercise("Glute Bridge", "Strength", "Glutes", "Beginner", ["Bodyweight", "Dumbbell"], ["Lie on your back with knees bent.", "Drive through heels and squeeze glutes at the top."], ["Glute activation", "Hip stability", "Low-equipment training"]),
    exercise("Romanian Deadlift", "Strength", "Hamstrings", "Intermediate", ["Barbell", "Dumbbells"], ["Hold weight in front of thighs and soften knees.", "Hinge hips back until hamstrings stretch, then stand tall."], ["Hamstring strength", "Hip hinge", "Posterior-chain control"]),
    exercise("Conventional Deadlift", "Strength", "Back", "Advanced", ["Barbell"], ["Set feet under the bar and brace hard.", "Push the floor away and stand tall without overextending."], ["Full-body strength", "Posterior-chain power", "Grip strength"]),
    exercise("Trap Bar Deadlift", "Strength", "Full Body", "Intermediate", ["Trap Bar"], ["Stand inside the trap bar and grip handles.", "Brace, push through the floor, and stand tall."], ["Full-body strength", "Lower-back friendly setup", "Power development"]),
    exercise("Sumo Deadlift", "Strength", "Hamstrings", "Advanced", ["Barbell"], ["Set a wide stance with toes turned out.", "Brace, push knees out, and drive the bar up close to the body."], ["Hip strength", "Posterior-chain power", "Adductor strength"]),
    exercise("Lying Leg Curl", "Strength", "Hamstrings", "Beginner", ["Leg Curl Machine"], ["Set the pad just above your heels.", "Curl smoothly, pause, and lower under control."], ["Hamstring isolation", "Knee flexion strength", "Controlled volume"]),
    exercise("Seated Leg Curl", "Strength", "Hamstrings", "Beginner", ["Seated Leg Curl Machine"], ["Lock thighs under the pad.", "Curl heels down and back, then return slowly."], ["Hamstring isolation", "Joint control", "Machine stability"]),
    exercise("Leg Extension", "Strength", "Quadriceps", "Beginner", ["Leg Extension Machine"], ["Set the pad above your ankles.", "Extend knees, squeeze quads, then lower slowly."], ["Quad isolation", "Knee extension strength", "Controlled tempo"]),
    exercise("Standing Calf Raise", "Strength", "Calves", "Beginner", ["Calf Raise Machine", "Dumbbells"], ["Stand tall with balls of feet on the platform.", "Rise high onto toes, pause, then lower fully."], ["Calf strength", "Ankle stability", "Lower-leg endurance"]),
    exercise("Seated Calf Raise", "Strength", "Calves", "Beginner", ["Seated Calf Raise Machine"], ["Place knees under the pad and feet on the platform.", "Raise heels, pause, then lower with control."], ["Soleus strength", "Ankle control", "Lower-leg endurance"]),
    exercise("Bench Press", "Strength", "Chest", "Intermediate", ["Barbell", "Bench"], ["Set shoulder blades down and back on the bench.", "Lower bar to mid-chest and press up with control."], ["Chest strength", "Triceps strength", "Pressing power"]),
    exercise("Incline Bench Press", "Strength", "Chest", "Intermediate", ["Barbell", "Incline Bench"], ["Set the bench to a moderate incline.", "Lower to upper chest and press without shrugging."], ["Upper-chest strength", "Shoulder stability", "Pressing strength"]),
    exercise("Dumbbell Bench Press", "Strength", "Chest", "Beginner", ["Dumbbells", "Bench"], ["Hold dumbbells over chest with wrists stacked.", "Lower elbows under control and press back up."], ["Chest strength", "Range of motion", "Shoulder control"]),
    exercise("Incline Dumbbell Press", "Strength", "Chest", "Intermediate", ["Dumbbells", "Incline Bench"], ["Set a slight-to-moderate incline.", "Press dumbbells up while keeping shoulder blades stable."], ["Upper-chest strength", "Pressing balance", "Shoulder control"]),
    exercise("Machine Chest Press", "Strength", "Chest", "Beginner", ["Chest Press Machine"], ["Set handles at mid-chest height.", "Press forward, pause, and return slowly."], ["Chest strength", "Stable setup", "Beginner-friendly pressing"]),
    exercise("Cable Chest Fly", "Strength", "Chest", "Intermediate", ["Cable Machine"], ["Set pulleys around chest height and step forward.", "Bring hands together in an arc while keeping elbows soft."], ["Chest isolation", "Shoulder control", "Muscle tension"]),
    exercise("Pec Deck Fly", "Strength", "Chest", "Beginner", ["Pec Deck Machine"], ["Set seat so handles align with chest.", "Bring arms together, squeeze, then return slowly."], ["Chest isolation", "Controlled range", "Machine stability"]),
    exercise("Push-Up", "Strength", "Chest", "Beginner", ["Bodyweight"], ["Start in a strong plank with hands under shoulders.", "Lower as one unit and press back up."], ["Upper-body strength", "Core tension", "No-equipment training"]),
    exercise("Pull-Up", "Strength", "Back", "Advanced", ["Pull-Up Bar"], ["Hang from the bar with active shoulders.", "Pull chest toward bar, then lower under control."], ["Back strength", "Grip strength", "Bodyweight control"]),
    exercise("Assisted Pull-Up", "Strength", "Back", "Beginner", ["Assisted Pull-Up Machine", "Band"], ["Set assistance so reps are controlled.", "Pull elbows down and lower slowly."], ["Back strength", "Pulling pattern", "Progression to pull-ups"]),
    exercise("Lat Pulldown", "Strength", "Back", "Beginner", ["Lat Pulldown Machine"], ["Grip the bar slightly wider than shoulders.", "Pull elbows down toward ribs and return with control."], ["Lat strength", "Upper-back control", "Pulling volume"]),
    exercise("Seated Cable Row", "Strength", "Back", "Beginner", ["Cable Row Machine"], ["Sit tall with knees soft and arms extended.", "Pull handles to torso while squeezing shoulder blades."], ["Mid-back strength", "Posture", "Pulling control"]),
    exercise("Bent-Over Barbell Row", "Strength", "Back", "Intermediate", ["Barbell"], ["Hinge forward with a flat back.", "Row bar toward lower ribs and lower with control."], ["Back thickness", "Hip hinge endurance", "Grip strength"]),
    exercise("One-Arm Dumbbell Row", "Strength", "Back", "Beginner", ["Dumbbell", "Bench"], ["Support one hand and knee on a bench.", "Row dumbbell toward hip, then lower fully."], ["Lat strength", "Single-side control", "Back stability"]),
    exercise("Chest-Supported Row", "Strength", "Back", "Intermediate", ["Incline Bench", "Dumbbells"], ["Lie chest-down on an incline bench.", "Row weights toward ribs without lifting chest."], ["Back strength", "Low-back support", "Scapular control"]),
    exercise("T-Bar Row", "Strength", "Back", "Intermediate", ["T-Bar Row Machine"], ["Set chest or hip support and brace.", "Pull handle toward torso, pause, and lower."], ["Back thickness", "Grip strength", "Heavy rowing"]),
    exercise("Face Pull", "Strength", "Shoulders", "Beginner", ["Cable Machine", "Rope Attachment"], ["Set cable around face height.", "Pull rope toward face with elbows high and squeeze rear delts."], ["Rear-delt strength", "Shoulder health", "Posture"]),
    exercise("Reverse Pec Deck", "Strength", "Shoulders", "Beginner", ["Reverse Pec Deck Machine"], ["Sit facing the pad with handles at shoulder height.", "Open arms wide and squeeze rear shoulders."], ["Rear-delt isolation", "Upper-back posture", "Shoulder balance"]),
    exercise("Overhead Press", "Strength", "Shoulders", "Intermediate", ["Barbell"], ["Start bar at upper chest and brace glutes.", "Press overhead, then lower under control."], ["Shoulder strength", "Triceps strength", "Core stability"]),
    exercise("Dumbbell Shoulder Press", "Strength", "Shoulders", "Beginner", ["Dumbbells", "Bench"], ["Hold dumbbells at shoulder height.", "Press overhead without arching low back."], ["Shoulder strength", "Pressing balance", "Upper-body control"]),
    exercise("Arnold Press", "Strength", "Shoulders", "Intermediate", ["Dumbbells"], ["Start palms facing you at shoulder height.", "Rotate palms out as you press overhead."], ["Shoulder strength", "Range of motion", "Pressing control"]),
    exercise("Lateral Raise", "Strength", "Shoulders", "Beginner", ["Dumbbells"], ["Stand tall with weights at sides.", "Raise arms to shoulder height with elbows slightly bent."], ["Side-delt isolation", "Shoulder width", "Light-load control"]),
    exercise("Cable Lateral Raise", "Strength", "Shoulders", "Intermediate", ["Cable Machine"], ["Set cable low and stand side-on.", "Raise arm out to the side under constant tension."], ["Side-delt tension", "Shoulder control", "Isolation strength"]),
    exercise("Upright Row", "Strength", "Shoulders", "Intermediate", ["Barbell", "Dumbbells", "Cable"], ["Hold weight in front with close-to-moderate grip.", "Pull elbows upward only as high as comfortable."], ["Shoulder strength", "Upper-trap work", "Controlled pulling"]),
    exercise("Barbell Curl", "Strength", "Biceps", "Beginner", ["Barbell"], ["Stand tall with elbows close to sides.", "Curl bar up without swinging, then lower slowly."], ["Biceps strength", "Grip strength", "Arm size"]),
    exercise("Dumbbell Curl", "Strength", "Biceps", "Beginner", ["Dumbbells"], ["Hold dumbbells at sides with palms forward.", "Curl with elbows still, then lower under control."], ["Biceps strength", "Arm control", "Single-side balance"]),
    exercise("Hammer Curl", "Strength", "Biceps", "Beginner", ["Dumbbells"], ["Hold dumbbells with thumbs up.", "Curl without rotating wrists, then lower slowly."], ["Brachialis strength", "Forearm strength", "Grip support"]),
    exercise("Preacher Curl", "Strength", "Biceps", "Intermediate", ["Preacher Bench", "EZ Bar"], ["Set upper arms against the pad.", "Curl up while keeping arms planted, then lower fully."], ["Biceps isolation", "Controlled range", "Arm strength"]),
    exercise("Cable Curl", "Strength", "Biceps", "Beginner", ["Cable Machine"], ["Set cable low and stand tall.", "Curl handles up while keeping elbows by your sides."], ["Constant tension", "Biceps isolation", "Arm control"]),
    exercise("Triceps Pushdown", "Strength", "Triceps", "Beginner", ["Cable Machine"], ["Set cable high and keep elbows pinned.", "Press handle down, squeeze triceps, then return slowly."], ["Triceps isolation", "Elbow extension strength", "Arm definition"]),
    exercise("Rope Triceps Pushdown", "Strength", "Triceps", "Beginner", ["Cable Machine", "Rope Attachment"], ["Grip rope with elbows close to ribs.", "Push down and separate rope ends at the bottom."], ["Triceps strength", "Elbow control", "Cable tension"]),
    exercise("Overhead Triceps Extension", "Strength", "Triceps", "Intermediate", ["Dumbbell", "Cable"], ["Hold weight overhead with elbows pointing forward.", "Lower behind head and extend arms smoothly."], ["Long-head triceps strength", "Arm size", "Overhead control"]),
    exercise("Close-Grip Bench Press", "Strength", "Triceps", "Intermediate", ["Barbell", "Bench"], ["Grip bar slightly inside shoulder width.", "Lower to lower chest and press while keeping elbows controlled."], ["Triceps strength", "Pressing power", "Chest support"]),
    exercise("Skull Crusher", "Strength", "Triceps", "Intermediate", ["EZ Bar", "Dumbbells", "Bench"], ["Lie on a bench with arms extended.", "Bend elbows to lower weight near forehead, then extend."], ["Triceps isolation", "Arm strength", "Elbow control"]),
    exercise("Dip", "Strength", "Triceps", "Advanced", ["Dip Bars"], ["Support yourself on bars with shoulders down.", "Lower under control and press back up."], ["Triceps strength", "Chest support", "Bodyweight control"]),
    exercise("Assisted Dip", "Strength", "Triceps", "Beginner", ["Assisted Dip Machine"], ["Set assistance for smooth reps.", "Lower with control and press through hands."], ["Pressing strength", "Triceps development", "Beginner progression"]),
    exercise("Plank", "Strength", "Core", "Beginner", ["Bodyweight"], ["Set elbows under shoulders and step feet back.", "Hold a straight line while breathing steadily."], ["Core stability", "Posture", "Full-body tension"]),
    exercise("Side Plank", "Strength", "Core", "Beginner", ["Bodyweight"], ["Stack elbow under shoulder and feet together.", "Lift hips and hold a straight side-body line."], ["Oblique strength", "Hip stability", "Core endurance"]),
    exercise("Hanging Knee Raise", "Strength", "Core", "Intermediate", ["Pull-Up Bar", "Captain's Chair"], ["Hang or support yourself with shoulders active.", "Lift knees toward chest and lower slowly."], ["Core strength", "Hip flexor control", "Grip support"]),
    exercise("Cable Crunch", "Strength", "Core", "Intermediate", ["Cable Machine", "Rope Attachment"], ["Kneel facing a high cable with rope near forehead.", "Crunch ribs toward hips and return with control."], ["Ab isolation", "Loaded core work", "Spinal flexion control"]),
    exercise("Ab Wheel Rollout", "Strength", "Core", "Advanced", ["Ab Wheel"], ["Start kneeling with wheel under shoulders.", "Roll forward only as far as you can control, then pull back."], ["Core strength", "Anti-extension control", "Shoulder stability"]),
    exercise("Pallof Press", "Strength", "Core", "Beginner", ["Cable Machine", "Band"], ["Stand side-on to the cable and hold handle at chest.", "Press straight out without rotating, then return."], ["Anti-rotation strength", "Core stability", "Posture"]),
    exercise("Russian Twist", "Strength", "Core", "Beginner", ["Bodyweight", "Medicine Ball", "Dumbbell"], ["Sit tall with knees bent and lean back slightly.", "Rotate torso side to side under control."], ["Oblique strength", "Rotational control", "Core endurance"]),
    exercise("Farmer's Carry", "Strength", "Full Body", "Beginner", ["Dumbbells", "Kettlebells"], ["Hold heavy weights at your sides.", "Walk tall with ribs down and shoulders stable."], ["Grip strength", "Core stability", "Loaded conditioning"]),
    exercise("Sled Push", "Strength", "Full Body", "Intermediate", ["Sled"], ["Lean into sled handles with a braced torso.", "Drive knees forward and push with steady steps."], ["Leg power", "Conditioning", "Low-impact effort"]),
    exercise("Kettlebell Swing", "Strength", "Full Body", "Intermediate", ["Kettlebell"], ["Hinge hips back with kettlebell between legs.", "Snap hips forward to float the bell to chest height."], ["Hip power", "Conditioning", "Posterior-chain strength"]),
    exercise("Clean Pull", "Strength", "Full Body", "Advanced", ["Barbell"], ["Set up like a deadlift with chest tall.", "Drive powerfully through legs and shrug at the top."], ["Power development", "Posterior-chain strength", "Athletic training"]),
    exercise("Power Clean", "Strength", "Full Body", "Advanced", ["Barbell"], ["Pull bar from floor with speed and close contact.", "Catch in a quarter squat with elbows high."], ["Explosive power", "Coordination", "Full-body strength"]),
    exercise("Medicine Ball Slam", "Strength", "Full Body", "Beginner", ["Medicine Ball"], ["Raise ball overhead with ribs down.", "Slam to the floor and reset with control."], ["Power", "Conditioning", "Stress release"]),
    exercise("Battle Ropes", "Cardio", "Full Body", "Beginner", ["Battle Ropes"], ["Set an athletic stance and grip rope ends.", "Create waves with steady arm motion while bracing core."], ["Conditioning", "Shoulder endurance", "Full-body effort"]),
    exercise("Rowing Machine", "Cardio", "Full Body", "Beginner", ["Rowing Machine"], ["Push with legs, lean slightly, then pull handle to ribs.", "Return arms, torso, then legs in sequence."], ["Cardio fitness", "Back endurance", "Low-impact conditioning"]),
    exercise("Assault Bike", "Cardio", "Full Body", "Intermediate", ["Air Bike"], ["Set seat height and start with easy cadence.", "Drive arms and legs together for intervals or steady work."], ["Conditioning", "High-intensity intervals", "Full-body endurance"]),
    exercise("Treadmill Incline Walk", "Cardio", "Legs", "Beginner", ["Treadmill"], ["Set a comfortable incline and walking pace.", "Stand tall and avoid holding the rails unless needed."], ["Low-impact cardio", "Leg endurance", "Heart health"]),
    exercise("Stair Climber", "Cardio", "Glutes", "Intermediate", ["Stair Climber"], ["Step with full foot contact and tall posture.", "Use rails lightly and keep a steady rhythm."], ["Cardio fitness", "Glute endurance", "Leg conditioning"]),
    exercise("Elliptical", "Cardio", "Full Body", "Beginner", ["Elliptical Machine"], ["Set resistance to a sustainable level.", "Keep posture tall and move smoothly."], ["Low-impact cardio", "Endurance", "Joint-friendly conditioning"]),
    exercise("Smith Machine Squat", "Strength", "Quadriceps", "Beginner", ["Smith Machine"], ["Set bar at shoulder height and feet slightly forward.", "Squat under control and press through mid-foot."], ["Leg strength", "Stable bar path", "Beginner-friendly squatting"]),
    exercise("Smith Machine Bench Press", "Strength", "Chest", "Beginner", ["Smith Machine", "Bench"], ["Set bench so bar lowers to mid-chest.", "Lower with control and press smoothly."], ["Chest strength", "Stable pressing", "Confidence under load"]),
    exercise("Smith Machine Shoulder Press", "Strength", "Shoulders", "Intermediate", ["Smith Machine", "Bench"], ["Sit upright under the bar.", "Press overhead and lower to comfortable depth."], ["Shoulder strength", "Stable bar path", "Triceps strength"]),
    exercise("Cable Wood Chop", "Strength", "Core", "Intermediate", ["Cable Machine"], ["Set cable high or low depending on direction.", "Rotate through torso while keeping hips controlled."], ["Rotational strength", "Core control", "Athletic movement"]),
    exercise("Cable Pull-Through", "Strength", "Glutes", "Beginner", ["Cable Machine", "Rope Attachment"], ["Face away from low cable with rope between legs.", "Hinge back, then drive hips forward to stand."], ["Hip hinge", "Glute strength", "Hamstring control"]),
    exercise("Good Morning", "Strength", "Hamstrings", "Advanced", ["Barbell"], ["Set bar across upper back and brace.", "Hinge hips back with a flat back, then stand tall."], ["Posterior-chain strength", "Hip hinge control", "Back endurance"]),
    exercise("Back Extension", "Strength", "Back", "Beginner", ["Back Extension Bench"], ["Set pad below hips and brace core.", "Hinge down and raise torso to neutral."], ["Low-back endurance", "Glute strength", "Posterior-chain control"]),
    exercise("Hip Abduction Machine", "Strength", "Glutes", "Beginner", ["Hip Abduction Machine"], ["Sit tall with knees against pads.", "Press knees outward, pause, and return slowly."], ["Glute medius strength", "Hip stability", "Machine isolation"]),
    exercise("Hip Adduction Machine", "Strength", "Legs", "Beginner", ["Hip Adduction Machine"], ["Sit tall with pads outside knees.", "Bring knees together under control, then return."], ["Inner-thigh strength", "Hip control", "Machine isolation"]),
    exercise("Landmine Press", "Strength", "Shoulders", "Intermediate", ["Barbell", "Landmine Attachment"], ["Hold bar end at shoulder height.", "Press forward and up, then lower with control."], ["Shoulder strength", "Core stability", "Joint-friendly pressing"]),
    exercise("Landmine Row", "Strength", "Back", "Intermediate", ["Barbell", "Landmine Attachment"], ["Hinge over the bar end and brace.", "Row handle toward torso and lower fully."], ["Back strength", "Grip strength", "Loaded rowing"]),
    exercise("Landmine Squat", "Strength", "Legs", "Beginner", ["Barbell", "Landmine Attachment"], ["Hold bar end at chest height.", "Squat down and drive up through mid-foot."], ["Leg strength", "Core control", "Beginner-friendly loading"]),
    exercise("Dumbbell Pullover", "Strength", "Back", "Intermediate", ["Dumbbell", "Bench"], ["Lie on a bench holding one dumbbell over chest.", "Lower behind head with soft elbows, then pull back over chest."], ["Lat engagement", "Chest stretch", "Shoulder mobility"]),
    exercise("Machine Shoulder Press", "Strength", "Shoulders", "Beginner", ["Shoulder Press Machine"], ["Set handles around shoulder height.", "Press overhead and return under control."], ["Shoulder strength", "Stable setup", "Beginner-friendly pressing"]),
    exercise("Machine Row", "Strength", "Back", "Beginner", ["Row Machine"], ["Set chest pad and handles to comfortable height.", "Pull elbows back and squeeze shoulder blades."], ["Back strength", "Posture", "Machine stability"]),
    exercise("Cable Rear Delt Fly", "Strength", "Shoulders", "Intermediate", ["Cable Machine"], ["Set cables around shoulder height and cross handles.", "Open arms wide with soft elbows."], ["Rear-delt strength", "Shoulder balance", "Posture"]),
    exercise("Dumbbell Chest Fly", "Strength", "Chest", "Intermediate", ["Dumbbells", "Bench"], ["Hold dumbbells over chest with palms facing.", "Open arms in an arc and bring them back together."], ["Chest isolation", "Range of motion", "Shoulder control"]),
    exercise("Single-Leg Romanian Deadlift", "Strength", "Hamstrings", "Intermediate", ["Dumbbells", "Kettlebell"], ["Stand on one leg with weight in opposite hand.", "Hinge back while keeping hips square, then stand."], ["Balance", "Hamstring strength", "Hip stability"]),
    exercise("Box Squat", "Strength", "Quadriceps", "Beginner", ["Box", "Barbell", "Dumbbells"], ["Stand in front of a box at squat depth.", "Sit back lightly to the box, then stand without rocking."], ["Squat control", "Leg strength", "Depth consistency"]),
    exercise("Pause Squat", "Strength", "Quadriceps", "Advanced", ["Barbell", "Squat Rack"], ["Squat to depth and hold tension at the bottom.", "Drive up without bouncing."], ["Position strength", "Leg power", "Control under load"]),
    exercise("Dumbbell Floor Press", "Strength", "Chest", "Beginner", ["Dumbbells"], ["Lie on the floor with elbows near ribs.", "Press dumbbells up and lower until upper arms touch floor."], ["Chest strength", "Triceps strength", "Shoulder-friendly pressing"]),
    exercise("Cable Seated Row", "Strength", "Back", "Beginner", ["Cable Machine"], ["Sit tall and hold the handle with arms long.", "Pull toward torso while keeping ribs down."], ["Back strength", "Posture", "Pulling volume"]),
]


def get_firebase_app():
    import firebase_admin
    from firebase_admin import credentials

    if firebase_admin._apps:
        return firebase_admin.get_app()

    service_account_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    if service_account_json:
        return firebase_admin.initialize_app(
            credentials.Certificate(json.loads(service_account_json))
        )

    credentials_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
    if credentials_path:
        return firebase_admin.initialize_app(
            credentials.Certificate(credentials_path)
        )

    return firebase_admin.initialize_app()


def unique_exercises(items: Iterable[Exercise]) -> list[Exercise]:
    seen: set[str] = set()
    result: list[Exercise] = []
    for item in items:
        item_id = item["id"]
        if item_id in seen:
            raise ValueError(f"Duplicate exercise id: {item_id}")
        seen.add(item_id)
        result.append(item)
    return result


def firestore_value(value: Any) -> dict[str, Any]:
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, datetime):
        return {"timestampValue": value.isoformat().replace("+00:00", "Z")}
    if isinstance(value, list):
        return {"arrayValue": {"values": [firestore_value(item) for item in value]}}
    return {"stringValue": "" if value is None else str(value)}


def run_command(args: list[str]) -> str:
    return subprocess.check_output(args, text=True).strip()


def seed_exercises_with_gcloud_rest(exercises: list[Exercise]) -> None:
    project_id = (
        os.environ.get("GOOGLE_CLOUD_PROJECT")
        or os.environ.get("GCLOUD_PROJECT")
        or run_command(["gcloud", "config", "get-value", "project"])
    ).strip()
    if not project_id:
        raise RuntimeError("No Google Cloud project configured. Run: gcloud config set project YOUR_PROJECT_ID")

    token = run_command(["gcloud", "auth", "print-access-token"])
    if not token:
        raise RuntimeError("Could not get gcloud access token. Run: gcloud auth login")

    now = datetime.now(UTC)
    field_paths = [
        "id",
        "name",
        "type",
        "muscle",
        "difficulty",
        "description",
        "instructions",
        "equipment",
        "benefits",
        "instructionUrl",
        "videoUrl",
        "updatedAt",
    ]
    url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents:batchWrite"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    upserted = 0
    for start in range(0, len(exercises), 20):
        writes = []
        for item in exercises[start : start + 20]:
            payload = dict(item)
            payload["updatedAt"] = now
            writes.append(
                {
                    "update": {
                        "name": f"projects/{project_id}/databases/(default)/documents/exercises/{item['id']}",
                        "fields": {key: firestore_value(payload[key]) for key in field_paths},
                    },
                    "updateMask": {"fieldPaths": field_paths},
                }
            )

        response = requests.post(url, headers=headers, json={"writes": writes}, timeout=60)
        if response.status_code >= 400:
            raise RuntimeError(f"Firestore REST seed failed ({response.status_code}): {response.text}")
        upserted += len(writes)

    print(f"Seeded {upserted} exercise documents into Firestore using gcloud REST.")


def seed_exercises(*, dry_run: bool = False, auth: str = "firebase-admin") -> None:
    exercises = unique_exercises(EXERCISES)
    if dry_run:
        print(f"Dry run: {len(exercises)} exercise documents would be seeded.")
        for item in exercises[:12]:
            print(f"  - exercises/{item['id']}: {item['name']}")
        if len(exercises) > 12:
            print(f"  ... and {len(exercises) - 12} more")
        return

    if auth == "gcloud-rest":
        seed_exercises_with_gcloud_rest(exercises)
        return

    get_firebase_app()
    from firebase_admin import firestore

    db = firestore.client()
    collection = db.collection("exercises")
    now = datetime.now(UTC)

    upserted = 0
    batch = db.batch()
    pending_writes = 0

    for item in exercises:
        doc_ref = collection.document(item["id"])
        payload = dict(item)
        payload.update(
            {
                "updatedAt": now,
            }
        )

        batch.set(doc_ref, payload, merge=True)
        upserted += 1
        pending_writes += 1
        if pending_writes >= 450:
            batch.commit()
            batch = db.batch()
            pending_writes = 0

    if pending_writes:
        batch.commit()

    print(f"Seeded {upserted} exercise documents into Firestore.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed Firestore exercise catalog.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be seeded without writing to Firestore.",
    )
    parser.add_argument(
        "--auth",
        choices=("firebase-admin", "gcloud-rest"),
        default="firebase-admin",
        help="Authentication/write method to use. gcloud-rest uses the active gcloud account.",
    )
    args = parser.parse_args()
    seed_exercises(dry_run=args.dry_run, auth=args.auth)


if __name__ == "__main__":
    main()