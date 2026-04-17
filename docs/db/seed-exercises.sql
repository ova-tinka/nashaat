-- Seed data: 70+ exercises for the Nashaat exercise library.
-- Run after migration-exercise-schema.sql.

INSERT INTO exercises (name, description, muscle_groups, steps, difficulty_level, measurement_type, is_system) VALUES

-- ── CHEST ─────────────────────────────────────────────────────────────────────

('Bench Press',
 'The classic barbell bench press targets the pectorals, front deltoids, and triceps.',
 ARRAY['Chest', 'Triceps', 'Shoulders'],
 ARRAY['Lie flat on a bench with feet on the floor.', 'Grip the barbell slightly wider than shoulder-width.', 'Lower the bar to your mid-chest with control.', 'Press the bar back up to full arm extension.', 'Avoid locking out elbows completely at the top.'],
 'medium', 'reps_weight', true),

('Incline Bench Press',
 'Targets the upper chest with a 30–45° incline.',
 ARRAY['Upper Chest', 'Shoulders', 'Triceps'],
 ARRAY['Set bench to 30–45° incline.', 'Grip bar slightly wider than shoulder-width.', 'Lower bar to upper chest under control.', 'Drive bar up to full extension without locking elbows.'],
 'medium', 'reps_weight', true),

('Push-ups',
 'A bodyweight compound movement for chest, shoulders, and triceps.',
 ARRAY['Chest', 'Shoulders', 'Triceps'],
 ARRAY['Place hands slightly wider than shoulder-width on the floor.', 'Keep body in a straight line from head to heels.', 'Lower your chest to just above the floor.', 'Push back up to starting position.', 'Keep core tight throughout.'],
 'easy', 'reps_only', true),

('Dumbbell Flyes',
 'Isolation movement that stretches and contracts the pectoral muscles.',
 ARRAY['Chest'],
 ARRAY['Lie on a flat bench holding dumbbells above your chest.', 'With a slight bend in elbows, lower arms out to the sides.', 'Feel a stretch in the chest at the bottom.', 'Bring arms back together above your chest in an arc motion.'],
 'medium', 'reps_weight', true),

('Cable Crossover',
 'Uses cables to provide constant tension through the full range of motion.',
 ARRAY['Chest', 'Shoulders'],
 ARRAY['Set cables at shoulder height on both sides.', 'Stand in the centre holding a handle in each hand.', 'Lean slightly forward and bring handles together in front of you.', 'Squeeze chest at the peak contraction.', 'Return slowly to starting position.'],
 'medium', 'reps_weight', true),

('Dips (Chest)',
 'A compound pushing movement emphasising the lower chest.',
 ARRAY['Lower Chest', 'Triceps', 'Shoulders'],
 ARRAY['Grip parallel bars with arms straight.', 'Lean forward slightly to engage chest.', 'Lower yourself until elbows are at 90°.', 'Push back up to starting position.'],
 'hard', 'reps_only', true),

-- ── BACK ──────────────────────────────────────────────────────────────────────

('Pull-ups',
 'The gold-standard upper-body pulling exercise for width and strength.',
 ARRAY['Lats', 'Biceps', 'Upper Back'],
 ARRAY['Hang from a bar with palms facing away, shoulder-width apart.', 'Initiate the pull by retracting your shoulder blades.', 'Pull your chest to the bar keeping elbows close.', 'Lower yourself slowly to a full hang.', 'Avoid swinging.'],
 'hard', 'reps_only', true),

('Barbell Row',
 'A compound back exercise building thickness and strength.',
 ARRAY['Upper Back', 'Lats', 'Biceps', 'Rear Deltoids'],
 ARRAY['Hinge at hips, back flat, holding barbell with overhand grip.', 'Row the bar into your lower ribcage.', 'Squeeze shoulder blades together at the top.', 'Lower with control.', 'Maintain neutral spine throughout.'],
 'medium', 'reps_weight', true),

('Lat Pulldown',
 'Machine/cable movement targeting the latissimus dorsi.',
 ARRAY['Lats', 'Biceps', 'Upper Back'],
 ARRAY['Sit at the pulldown machine and grip the bar wider than shoulders.', 'Lean slightly back and pull the bar to your upper chest.', 'Squeeze lats at the bottom.', 'Let the bar rise with full arm extension.'],
 'easy', 'reps_weight', true),

('Seated Cable Row',
 'Builds mid-back thickness and reinforces good posture.',
 ARRAY['Mid Back', 'Lats', 'Biceps'],
 ARRAY['Sit with legs slightly bent, grip the cable handle.', 'Start with arms fully extended and back upright.', 'Pull the handle to your lower stomach.', 'Squeeze shoulder blades and hold briefly.', 'Return to start under control.'],
 'easy', 'reps_weight', true),

('Deadlift',
 'The king of compound lifts — works the entire posterior chain.',
 ARRAY['Lower Back', 'Glutes', 'Hamstrings', 'Traps'],
 ARRAY['Stand with feet hip-width, bar over mid-foot.', 'Hinge down and grip bar just outside legs.', 'Keep chest up and back flat.', 'Drive through heels and extend hips to stand up.', 'Lower bar to floor with control.'],
 'hard', 'reps_weight', true),

('Face Pulls',
 'Strengthens rear deltoids and external rotators for shoulder health.',
 ARRAY['Rear Deltoids', 'Upper Back', 'Rotator Cuff'],
 ARRAY['Attach a rope to a cable at face height.', 'Pull the rope toward your face with elbows flared high.', 'Externally rotate wrists at the end of the movement.', 'Hold briefly and return slowly.'],
 'easy', 'reps_weight', true),

-- ── SHOULDERS ─────────────────────────────────────────────────────────────────

('Overhead Press',
 'The primary barbell shoulder pressing movement.',
 ARRAY['Shoulders', 'Triceps', 'Upper Chest'],
 ARRAY['Stand with bar at shoulder height, grip just outside shoulders.', 'Brace core and press the bar straight overhead.', 'At the top, shrug traps slightly and lock out arms.', 'Lower bar back to shoulders with control.'],
 'medium', 'reps_weight', true),

('Dumbbell Lateral Raise',
 'Isolation exercise for the medial deltoid.',
 ARRAY['Shoulders'],
 ARRAY['Stand holding dumbbells at your sides.', 'With a slight elbow bend, raise arms out to shoulder height.', 'Lead with elbows rather than hands.', 'Lower slowly and with control.'],
 'easy', 'reps_weight', true),

('Arnold Press',
 'A 180-degree rotation during the press recruits all three delt heads.',
 ARRAY['Shoulders', 'Triceps'],
 ARRAY['Hold dumbbells in front of you with palms facing you.', 'As you press up, rotate palms outward.', 'At the top, palms face forward.', 'Reverse the rotation on the way down.'],
 'medium', 'reps_weight', true),

('Front Raise',
 'Isolates the anterior deltoid.',
 ARRAY['Front Deltoid'],
 ARRAY['Hold dumbbells in front of thighs.', 'Raise one or both arms straight to shoulder height.', 'Keep a slight elbow bend.', 'Lower slowly.'],
 'easy', 'reps_weight', true),

('Upright Row',
 'Works the traps and lateral deltoids.',
 ARRAY['Shoulders', 'Traps'],
 ARRAY['Hold a barbell or dumbbells in front of you.', 'Pull straight up toward your chin, leading with elbows.', 'Keep bar close to your body.', 'Lower under control.'],
 'medium', 'reps_weight', true),

-- ── BICEPS ────────────────────────────────────────────────────────────────────

('Barbell Curl',
 'Standard bicep isolation with maximum loading potential.',
 ARRAY['Biceps'],
 ARRAY['Stand holding a barbell with underhand grip, arms extended.', 'Curl the bar to shoulder height without swinging.', 'Squeeze biceps at the top.', 'Lower slowly to full extension.'],
 'easy', 'reps_weight', true),

('Dumbbell Hammer Curl',
 'Targets the brachialis and long head of the biceps.',
 ARRAY['Biceps', 'Brachialis'],
 ARRAY['Stand holding dumbbells with a neutral grip (palms facing each other).', 'Curl both or alternating arms to shoulder height.', 'Keep elbows pinned at your sides.', 'Lower with control.'],
 'easy', 'reps_weight', true),

('Incline Dumbbell Curl',
 'Stretches the long head of the bicep for fuller development.',
 ARRAY['Biceps'],
 ARRAY['Lie on a 45–60° incline bench.', 'Let arms hang straight down holding dumbbells.', 'Curl without allowing elbows to swing forward.', 'Squeeze and lower slowly.'],
 'medium', 'reps_weight', true),

('Concentration Curl',
 'Isolates the bicep by bracing the elbow against the thigh.',
 ARRAY['Biceps'],
 ARRAY['Sit on a bench, lean forward and brace elbow on inner thigh.', 'Hold a dumbbell and curl it toward your shoulder.', 'Focus on squeezing the bicep peak.', 'Lower fully and repeat.'],
 'easy', 'reps_weight', true),

-- ── TRICEPS ───────────────────────────────────────────────────────────────────

('Tricep Pushdown',
 'Cable exercise isolating all three heads of the triceps.',
 ARRAY['Triceps'],
 ARRAY['Attach a bar or rope to a high cable.', 'Stand with upper arms pinned to your sides.', 'Push the attachment down to full extension.', 'Squeeze triceps at the bottom.', 'Return slowly keeping upper arms still.'],
 'easy', 'reps_weight', true),

('Skull Crushers',
 'Lying extension that maximally loads the triceps.',
 ARRAY['Triceps'],
 ARRAY['Lie on a bench holding a barbell or EZ bar above your chest.', 'Bend elbows and lower the bar toward your forehead.', 'Keep upper arms perpendicular to the floor.', 'Extend elbows back to start.'],
 'medium', 'reps_weight', true),

('Close-Grip Bench Press',
 'Compound pressing movement with emphasis on triceps.',
 ARRAY['Triceps', 'Chest'],
 ARRAY['Grip a barbell with hands about shoulder-width apart.', 'Lower bar to lower chest keeping elbows close.', 'Press back up to full extension.'],
 'medium', 'reps_weight', true),

('Diamond Push-ups',
 'A push-up variation that shifts load to the triceps.',
 ARRAY['Triceps', 'Chest'],
 ARRAY['Form a diamond shape with index fingers and thumbs on the floor.', 'Keep elbows close to your body as you lower down.', 'Push back up to full extension.'],
 'medium', 'reps_only', true),

-- ── LEGS ─────────────────────────────────────────────────────────────────────

('Squat',
 'The fundamental lower body strength movement.',
 ARRAY['Quads', 'Glutes', 'Hamstrings', 'Core'],
 ARRAY['Stand with feet shoulder-width apart.', 'Brace core and hinge at hips and knees simultaneously.', 'Lower until thighs are parallel to the floor.', 'Drive through heels to stand back up.', 'Keep chest up and knees tracking over toes.'],
 'medium', 'reps_weight', true),

('Romanian Deadlift',
 'Targets hamstrings and glutes through a hip-hinge pattern.',
 ARRAY['Hamstrings', 'Glutes', 'Lower Back'],
 ARRAY['Stand holding a barbell at hip level.', 'Hinge at hips pushing them back, bar stays close to legs.', 'Lower until you feel a stretch in hamstrings.', 'Drive hips forward to return to standing.'],
 'medium', 'reps_weight', true),

('Leg Press',
 'Machine-based quad dominant leg exercise.',
 ARRAY['Quads', 'Glutes', 'Hamstrings'],
 ARRAY['Sit in the leg press machine with feet shoulder-width on the platform.', 'Lower the sled until knees reach ~90°.', 'Press through heels to full extension.', 'Do not lock out knees fully.'],
 'easy', 'reps_weight', true),

('Lunges',
 'Unilateral leg exercise improving balance and symmetry.',
 ARRAY['Quads', 'Glutes', 'Hamstrings'],
 ARRAY['Stand with feet together.', 'Step one foot forward and lower back knee toward the floor.', 'Push through the front heel to return to start.', 'Alternate legs each rep.'],
 'easy', 'reps_weight', true),

('Bulgarian Split Squat',
 'Single-leg squat with rear foot elevated — excellent for quad and glute development.',
 ARRAY['Quads', 'Glutes'],
 ARRAY['Place one foot elevated on a bench behind you.', 'Hold dumbbells or a barbell.', 'Lower front knee toward the floor.', 'Drive through front heel to stand.', 'Complete all reps one side then switch.'],
 'hard', 'reps_weight', true),

('Leg Curl',
 'Isolation movement for the hamstrings.',
 ARRAY['Hamstrings'],
 ARRAY['Lie face-down on the leg curl machine.', 'Place the pad just above your heels.', 'Curl legs toward glutes.', 'Squeeze hamstrings at the top and lower slowly.'],
 'easy', 'reps_weight', true),

('Calf Raise',
 'Isolation movement for the gastrocnemius and soleus.',
 ARRAY['Calves'],
 ARRAY['Stand with the balls of your feet on an elevated surface.', 'Lower heels as far as possible.', 'Drive up onto your toes as high as you can.', 'Hold at the top briefly.', 'Lower with control.'],
 'easy', 'reps_weight', true),

('Hip Thrust',
 'The best glute activation exercise with a barbell.',
 ARRAY['Glutes', 'Hamstrings'],
 ARRAY['Sit with upper back against a bench, barbell over hips.', 'Drive hips up until body is horizontal.', 'Squeeze glutes hard at the top.', 'Lower hips toward the floor and repeat.'],
 'medium', 'reps_weight', true),

-- ── CORE ─────────────────────────────────────────────────────────────────────

('Plank',
 'Isometric core exercise building stability and endurance.',
 ARRAY['Core', 'Shoulders'],
 ARRAY['Place forearms on the floor with elbows under shoulders.', 'Form a straight line from head to heels.', 'Engage core and squeeze glutes.', 'Hold the position without letting hips drop or rise.'],
 'easy', 'time_only', true),

('Crunches',
 'Basic flexion exercise targeting the rectus abdominis.',
 ARRAY['Core', 'Abs'],
 ARRAY['Lie on your back with knees bent and feet flat.', 'Place hands behind head, elbows out.', 'Curl shoulders off the floor contracting abs.', 'Lower slowly without fully relaxing.'],
 'easy', 'reps_only', true),

('Bicycle Crunch',
 'Rotational crunch targeting obliques and rectus abdominis.',
 ARRAY['Abs', 'Obliques'],
 ARRAY['Lie on your back with hands behind head.', 'Bring opposite elbow to opposite knee.', 'Extend the other leg out straight.', 'Alternate sides in a pedalling motion.'],
 'easy', 'reps_only', true),

('Hanging Leg Raise',
 'Advanced core exercise building lower ab strength.',
 ARRAY['Abs', 'Hip Flexors'],
 ARRAY['Hang from a pull-up bar with arms extended.', 'Keep legs straight and raise them to hip height or higher.', 'Lower with control without swinging.'],
 'hard', 'reps_only', true),

('Russian Twist',
 'Rotational exercise for the obliques.',
 ARRAY['Obliques', 'Abs'],
 ARRAY['Sit on the floor with knees bent and feet slightly raised.', 'Hold a weight or clasp hands together.', 'Rotate torso to the left and touch the weight to the floor.', 'Rotate to the right and repeat.'],
 'medium', 'reps_weight', true),

('Dead Bug',
 'A safe, stable anti-extension core exercise.',
 ARRAY['Core', 'Abs'],
 ARRAY['Lie on your back with arms pointing to the ceiling.', 'Raise legs to a 90° table-top position.', 'Lower opposite arm and leg simultaneously toward the floor.', 'Return to start and alternate sides.', 'Keep lower back pressed into the floor.'],
 'easy', 'reps_only', true),

('Ab Wheel Rollout',
 'A challenging core anti-extension movement.',
 ARRAY['Core', 'Abs', 'Shoulders'],
 ARRAY['Kneel on the floor holding an ab wheel.', 'Slowly roll the wheel out in front of you.', 'Keep hips in line with shoulders.', 'Roll back in by contracting your abs.'],
 'hard', 'reps_only', true),

-- ── CARDIO ────────────────────────────────────────────────────────────────────

('Running',
 'Fundamental cardiovascular exercise for endurance and conditioning.',
 ARRAY['Cardio', 'Legs', 'Core'],
 ARRAY['Warm up with 5 minutes of brisk walking.', 'Run at a comfortable pace, breathing rhythmically.', 'Maintain an upright posture with relaxed shoulders.', 'Cool down with 5 minutes of easy jogging then walking.'],
 'easy', 'time_distance', true),

('Cycling',
 'Low-impact cardio excellent for leg endurance.',
 ARRAY['Cardio', 'Quads', 'Glutes'],
 ARRAY['Adjust seat height so knees are slightly bent at full extension.', 'Pedal at a comfortable cadence.', 'Vary resistance throughout the session.', 'Cool down with 3–5 minutes of easy pedalling.'],
 'easy', 'time_distance', true),

('Jump Rope',
 'High-intensity cardio improving coordination and conditioning.',
 ARRAY['Cardio', 'Calves', 'Shoulders'],
 ARRAY['Hold handles with a relaxed grip, rope behind feet.', 'Jump with small hops clearing the rope each rotation.', 'Keep jumps low to the ground to reduce fatigue.', 'Keep elbows close to sides and use wrists to rotate the rope.'],
 'medium', 'time_only', true),

('Burpees',
 'Full-body conditioning movement combining a squat, plank, and jump.',
 ARRAY['Full Body', 'Cardio'],
 ARRAY['Start standing, drop hands to the floor.', 'Jump feet back into a plank position.', 'Perform a push-up.', 'Jump feet back to hands.', 'Explode upward into a jump, clapping hands overhead.'],
 'hard', 'reps_only', true),

('Rowing (Machine)',
 'Full-body cardio hitting legs, back, and arms simultaneously.',
 ARRAY['Cardio', 'Back', 'Legs', 'Arms'],
 ARRAY['Sit on the rower and strap feet in.', 'Start with arms straight and lean slightly forward.', 'Drive through legs first, then lean back and pull handle to lower chest.', 'Extend arms, hinge forward, and bend legs to return.', 'Maintain a steady rhythm.'],
 'medium', 'time_distance', true),

('Box Jumps',
 'Explosive plyometric exercise building power and conditioning.',
 ARRAY['Legs', 'Glutes', 'Cardio'],
 ARRAY['Stand in front of a sturdy box.', 'Squat down and swing arms back.', 'Explode upward landing softly on the box in a squat.', 'Stand fully on the box.', 'Step down carefully and repeat.'],
 'hard', 'reps_only', true),

('Mountain Climbers',
 'Dynamic core exercise with a cardiovascular element.',
 ARRAY['Core', 'Shoulders', 'Cardio'],
 ARRAY['Start in a high plank position.', 'Drive one knee toward your chest.', 'Quickly switch legs in an alternating pattern.', 'Maintain a flat back and engaged core throughout.'],
 'medium', 'time_only', true),

('High Knees',
 'Running in place with exaggerated knee drive for conditioning.',
 ARRAY['Cardio', 'Core', 'Legs'],
 ARRAY['Stand with feet hip-width apart.', 'Drive one knee up toward your chest while driving opposite arm up.', 'Alternate legs quickly like a fast-paced run in place.', 'Land lightly on the balls of your feet.'],
 'easy', 'time_only', true),

-- ── FULL BODY ─────────────────────────────────────────────────────────────────

('Kettlebell Swing',
 'Explosive hip-hinge movement building power and cardiovascular capacity.',
 ARRAY['Glutes', 'Hamstrings', 'Core', 'Shoulders'],
 ARRAY['Stand with feet shoulder-width, kettlebell on the floor ahead of you.', 'Hinge at hips and grip the handle.', 'Hike the bell back between your legs.', 'Drive hips forward explosively to swing the bell to chest height.', 'Let the bell fall and hinge back to repeat.'],
 'medium', 'reps_weight', true),

('Thruster',
 'Combines a front squat with an overhead press — a full-body power movement.',
 ARRAY['Legs', 'Shoulders', 'Core'],
 ARRAY['Hold dumbbells or a barbell at shoulder height.', 'Squat to parallel.', 'Drive out of the squat and press the weight overhead.', 'Lower back to shoulders on the way down into the next squat.'],
 'hard', 'reps_weight', true),

('Turkish Get-Up',
 'A complex movement requiring coordination, stability, and full-body strength.',
 ARRAY['Full Body', 'Shoulders', 'Core'],
 ARRAY['Lie on your back holding a kettlebell in one hand above you.', 'Roll to your side and prop yourself up onto your elbow.', 'Push to your hand and sweep the opposite leg back to a kneeling position.', 'Stand up fully with the bell overhead.', 'Reverse the steps to return to the floor.'],
 'hard', 'reps_weight', true),

('Dumbbell Clean and Press',
 'An Olympic-style full body conditioning movement.',
 ARRAY['Full Body', 'Shoulders', 'Legs'],
 ARRAY['Hold dumbbells at your sides, slightly bent forward.', 'Explosively pull dumbbells up and rotate wrists to rack at shoulders.', 'Dip slightly and press overhead.', 'Lower to shoulders, then to sides to complete one rep.'],
 'hard', 'reps_weight', true),

-- ── MOBILITY / STRETCHING ─────────────────────────────────────────────────────

('Hip Flexor Stretch',
 'Relieves tightness in the hip flexors caused by prolonged sitting.',
 ARRAY['Hip Flexors'],
 ARRAY['Kneel on one knee with the other foot forward.', 'Push hips forward until you feel a stretch in front of the rear hip.', 'Keep torso upright.', 'Hold for 30–60 seconds and switch sides.'],
 'easy', 'time_only', true),

('Downward Dog',
 'A yoga pose stretching hamstrings, calves, and shoulders.',
 ARRAY['Hamstrings', 'Calves', 'Shoulders'],
 ARRAY['Start on hands and knees.', 'Push hips up and back forming an inverted V.', 'Press hands into the floor and lengthen the spine.', 'Alternate pressing heels toward the floor.', 'Hold and breathe.'],
 'easy', 'time_only', true),

('Cat-Cow Stretch',
 'A gentle spinal mobility flow for the lower back.',
 ARRAY['Lower Back', 'Core'],
 ARRAY['Start on hands and knees in a table-top position.', 'Inhale and arch your back downward (cow).', 'Exhale and round your spine upward (cat).', 'Move slowly between the two positions.'],
 'easy', 'time_only', true),

('Thoracic Rotation',
 'Improves upper back mobility essential for pressing and pulling movements.',
 ARRAY['Upper Back', 'Core'],
 ARRAY['Kneel on one knee or sit cross-legged.', 'Place hands behind head.', 'Rotate your upper body to one side as far as comfortable.', 'Return to centre and rotate to the other side.'],
 'easy', 'reps_only', true),

('World''s Greatest Stretch',
 'A multi-joint mobility sequence used as a dynamic warm-up.',
 ARRAY['Hip Flexors', 'Thoracic Spine', 'Hamstrings'],
 ARRAY['Step into a deep lunge.', 'Drop the back knee to the floor.', 'Place the inside hand on the floor.', 'Rotate the outside arm toward the ceiling.', 'Hold and switch sides.'],
 'easy', 'time_only', true),

('Foam Roll Lats',
 'Self-myofascial release for the latissimus dorsi.',
 ARRAY['Lats'],
 ARRAY['Lie on your side with a foam roller under your armpit.', 'Extend arm overhead.', 'Slowly roll along the length of the lat.', 'Pause on any tender spots.', 'Switch sides.'],
 'easy', 'time_only', true),

('Child Pose',
 'A restful yoga posture that gently stretches hips, thighs, and lower back.',
 ARRAY['Lower Back', 'Hip Flexors'],
 ARRAY['Kneel and sit back onto your heels.', 'Reach arms forward along the floor.', 'Lower forehead to the ground.', 'Breathe deeply into your back.', 'Hold for 30–90 seconds.'],
 'easy', 'time_only', true),

('Pigeon Pose',
 'A deep hip stretch targeting the hip rotators and glutes.',
 ARRAY['Glutes', 'Hip Rotators'],
 ARRAY['From a high plank, bring one knee forward behind your wrist.', 'Extend the opposite leg back along the floor.', 'Lower hips toward the floor and walk hands forward.', 'Hold for 45–60 seconds and switch sides.'],
 'medium', 'time_only', true),

('Standing Quad Stretch',
 'Simple standing stretch for the quadriceps.',
 ARRAY['Quads'],
 ARRAY['Stand on one leg with good posture.', 'Bend the other knee and hold the ankle behind you.', 'Keep knees together and stand tall.', 'Hold for 30 seconds and switch.'],
 'easy', 'time_only', true),

('Shoulder Cross-Body Stretch',
 'Stretches the posterior deltoid and rotator cuff.',
 ARRAY['Shoulders', 'Upper Back'],
 ARRAY['Bring one arm across your body at chest height.', 'Use the opposite arm to gently press it closer to your chest.', 'Feel a stretch in the back of the shoulder.', 'Hold 30 seconds and switch.'],
 'easy', 'time_only', true)

ON CONFLICT (name) DO NOTHING;
