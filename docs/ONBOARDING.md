# RouteReady: frontend onboarding for B and C

Read this once from top to bottom, then follow it step by step.

## 0. The project in one minute

A real van service takes university students to campus and home. The head plans each
day's rides by hand on WhatsApp. RouteReady is a web app that builds that daily plan
automatically. The head reviews and publishes it, students see their van, and captains
(drivers) see their trip with call, WhatsApp and navigate buttons.

Three people, three areas:
- A: backend (database, API, planning engine) and the frontend skeleton (routing, API helper).
- B: login, layout, inbox, and everything the head sees.
- C: everything students and captains see.

You do NOT need MySQL, WSL or the backend. The backend is being built at the same time.
Until it is live, your screens read fake data from a JSON file. That is on purpose.

## 1. Install once

1. Node.js, the LTS version, from https://nodejs.org
   Check in a terminal:  node -v   and   npm -v   (both must print a version number)
2. Git from https://git-scm.com
   Check:  git --version
3. VS Code from https://code.visualstudio.com
   Optional extensions: ESLint, Prettier.
4. A GitHub account. Send A your username, then accept the invitation email
   (or open https://github.com/notifications). You cannot clone before accepting.
5. Tell Git who you are (this labels your commits, it is not a login):

       git config --global user.name "Your Name"
       git config --global user.email "your-github-email@example.com"

## 2. Get the code

Pick a folder for projects (not inside OneDrive or Downloads), open a terminal there:

    git clone REPO_URL_HERE
    cd routeready
    code .

The first time you push, Git asks you to log in. Your GitHub password will NOT work.
Use a personal access token instead:
GitHub > Settings > Developer settings > Personal access tokens > Tokens (classic) >
Generate new token, tick "repo", copy it, and paste it as the password when asked.
(Save the token somewhere private; GitHub shows it once.)

## 3. Run the app (first time)

    cd frontend
    npm install
    cp .env.example .env
    npm run dev

- npm install downloads the libraries listed in package.json into node_modules.
  Never commit node_modules.
- cp .env.example .env creates your own settings file. On Windows without a Unix shell,
  copy the file by hand and rename the copy to .env. It is ignored by Git.
- npm run dev starts a local server and prints an address, usually http://localhost:5173.
  Open it. You should see "Login (B builds this)". If you do, your setup works.
  Stop the server with Ctrl+C.

Every time you pull and package.json changed, run npm install again. If the app
suddenly says "Failed to resolve import ...", this is almost always the cause.

## 4. Testing your screens without a login page

The login page is built by B, so until it is finished the app always sends you to /login.
Pretend you are logged in by saving a fake user in the browser. Open the app, press F12,
open the Console tab, and paste ONE of these lines, then press F5 to reload:

Student:
    localStorage.setItem('token','x'); localStorage.setItem('user', JSON.stringify({id:7,fullName:'Student 01',roles:['student']}));

Captain:
    localStorage.setItem('token','x'); localStorage.setItem('user', JSON.stringify({id:2,fullName:'Imran Captain',roles:['captain']}));

Head:
    localStorage.setItem('token','x'); localStorage.setItem('user', JSON.stringify({id:1,fullName:'Hamid Head',roles:['head','captain']}));

To log out and start again:  localStorage.clear()   then reload.

Notes:
- The console printing "undefined" after these lines is normal. It means the line ran.
- You must reload (F5) after changing the saved user. The app reads it once when it loads.
- Each role can only open its own area: /student, /captain, /head. Opening another one
  sends you back to your own.
- The tab must be on localhost:5173, because browser storage is separate per address.

## 5. Who owns which files

Only edit files in your own area. This is how we avoid merge conflicts.

    frontend/src/
      main.jsx, App.jsx        A   (routing: ask A if you need a new route)
      api/core.js              A   (the shared request helper)
      mock/mock-data.json      A   (copy of docs/mock-data.json)
      auth/                    B   (login page, auth state)
      layout/                  B   (top bar, logout)
      inbox/                   B   (inbox screen and unread badge, used by everyone)
      head/                    B   (all head screens)
      api/auth.js              B
      api/inbox.js             B
      api/head.js              B
      student/                 C   (all student screens)
      captain/                 C   (all captain screens)
      api/student.js           C
      api/captain.js           C

Each area has a placeholder page (HeadHome.jsx, StudentHome.jsx, CaptainHome.jsx, LoginPage.jsx).
Replace them with real screens. Inside your area you can organise files however you like.

Routes: /head/*, /student/*, /captain/* end with a star. That means you can add your own
sub-pages (for example /head/plan) inside your home component using React Router's
<Routes> and <Route>, without touching App.jsx.

## 6. How data works (read this carefully)

The contract, docs/API.md, lists every request and response. Build each screen from its
examples. The fake data for every example is in frontend/src/mock/mock-data.json.
Keys in it: login, me, meCaptain, shifts, schedule, rides, plan, eligibleCaptains,
captainTrips, notifications.

Screens never call fetch directly. Every server call is a function in your api file.
Each function has two branches: fake data now, real server later. Example for
frontend/src/api/student.js (C creates it):

    import { USE_MOCK, delay, request } from './core';
    import mock from '../mock/mock-data.json';

    export const getSchedule = () =>
      USE_MOCK ? delay(mock.schedule) : request('/api/me/schedule');

    export const saveSchedule = (days) =>
      USE_MOCK
        ? delay({ termId: 1, termName: 'Fall 2026', days })
        : request('/api/me/schedule', { method: 'PUT', body: JSON.stringify({ days }) });

Then a screen does:

    import { getSchedule } from '../api/student';
    // inside a component: call getSchedule() in useEffect, keep the result in useState

Rules of the fake mode:
- delay() waits 300 ms to imitate the network, so you can build loading states.
- Fake writes do not persist. Return a plausible response and update your component's state.
- When A says an endpoint is live, only that one function changes: the fake branch is
  removed. The screen does not change, because the real response has the same shape.

If a screen needs a field the contract does not have, do NOT invent it locally.
Change docs/API.md in a pull request, tell A, and A builds it.
If docs/mock-data.json changes, copy it again:  cp ../docs/mock-data.json src/mock/mock-data.json
(run from frontend/).

## 7. Git workflow, for every task

    git checkout main
    git pull
    git checkout -b feature/short-name
    # ... write code, check it in the browser ...
    git add .
    git status
    git commit -m "Short clear message"
    git push -u origin feature/short-name

1. Read git status before committing. You must NOT see .env or node_modules.
2. On GitHub, click "Compare & pull request", describe what you built in two lines.
3. Ask a teammate to review. Merge after one approval. Never push straight to main.
4. Keep pull requests small: one screen or one feature, ideally under 300 changed lines.
5. After a merge, go back to main and pull before starting the next branch.
6. If Git reports a conflict, do not delete files and do not panic. Message the team.

Installing a new library (npm install something) changes package.json. Mention it in the
pull request, so everyone knows to run npm install after pulling.

## 8. Rules

- Fake data only. Never real names, phone numbers, CNICs or photos, in code, screenshots or commits.
- Never commit .env or node_modules.
- Phone first: design for a narrow screen, then check a wider one. Students and captains use phones.
- Only edit your own files (section 5). Ask A for changes in App.jsx or api/core.js.
- Stuck for more than 30 minutes? Message the team with what you tried and the exact error text.
- A working simple screen beats an unfinished fancy one. Do the plain version first.

## 9. B: login, layout, inbox, head screens

Do them in this order. Each has a "done when" line.

1. Real login (auth/). The page asks for phone and password and calls login() from
   api/auth.js (fake data: mock.login). On success, call saveLogin(token, user) from the
   existing auth context (useAuth() in auth/AuthContext.jsx), then go to "/".
   The app sends each role to its own area. On a wrong password, show the error message.
   If mustChangePassword is true, go to /setup instead (A adds this route; C builds that page).
   Done when: entering any phone and password in fake mode logs you in and lands you on
   the right area.
2. Layout (layout/): a top bar with the user's name, a logout button (logout() from
   useAuth()), and a place for the inbox badge. Tell A when it is ready so A wraps the areas in it.
   Done when: every area shows the top bar and logout returns to /login.
3. Plan page (head/), the most important screen. Pick a date and a shift, a Generate
   button, one column per van listing its stops in order, an "Unplaced" banner when
   plan.unplaced is not empty, and a Publish button. Contract section 4, mock key: plan.
   Done when: the fake plan shows two van columns with students, and the unplaced banner
   shows Student 16 with the reason in plain words.
4. Move a student to another van (only if the target has a free seat, capacity 7) and
   Swap captain (dropdown from mock.eligibleCaptains). Draft plans only; published
   plans are read-only.
5. Inbox (inbox/): list newest first, unread highlighted, tap to mark read, a "mark all
   read" button, and an unread count badge in the top bar that refreshes every 30 seconds.
   Contract section 6, mock key: notifications. C's screens reuse this same component.
6. Later, when A has built the admin endpoints: users, vans, document verification, leaves.
   Contract sections for these will be added then.

## 10. C: student and captain screens

Do them in this order. Each has a "done when" line.

1. First-login page (student/): step 1 change password, step 2 set home location.
   Captains also enter CNIC, licence number and licence expiry (contract section 1).
   Location has three options. Build them in this order and stop when time runs out:
   a) "Use my current location" button (browser geolocation).
   b) Paste a Google Maps link, which calls /location/parse-maps-link.
   c) A map with a draggable pin. Install with:  npm install leaflet react-leaflet
      and add  import 'leaflet/dist/leaflet.css'  where the map is used. If npm reports a
      peer dependency error, do NOT use --force. Message A.
   The route for this page is /setup (A adds it). Build it as a normal component first.
   Done when: you can change a fake password and set a location by option a.
2. Weekly schedule editor (student/): Mon to Fri, a pickup and a dropoff dropdown per
   day. Only show valid shifts: pickup A, B, C, D and dropoff Y, Z, and D only on Tuesday
   and Thursday. At least one shift per day. Contract section 2, mock keys: schedule, shifts.
3. Ride cards (student/): the list from rides. Show the date, direction, shift, state
   (scheduled, assigned, unplaced, cancelled) and, when assigned, the captain, the van
   plate, the planned time, and Call and WhatsApp buttons.
   Call link:      tel:+923000000002
   WhatsApp link:  https://wa.me/923000000002   (no plus sign, no spaces)
4. Ride change form (student/): cancel, change shift, add an extra ride. Contract section 3.
5. Captain trip list (captain/): stops in order with the student's name, planned time and
   address note. Buttons: Call, WhatsApp, Navigate, Picked up, No-show (with undo), and
   Start trip / Complete trip. Mock key: captainTrips.
   Navigate link:  https://www.google.com/maps/dir/?api=1&destination=LAT,LNG
   Done when: marking a fake stop changes its colour on the screen.
6. Licence banner (captain/): shown when meCaptain.licenceExpiresInDays is 45 or less.
7. Use B's inbox component once B has merged it (section 9, step 5).
Also C writes the project README and the demo script near the end.

## 11. Working rhythm

- A short check-in every 2 to 3 days (15 minutes): show what runs, say what blocks you.
- Weekly demo of what works, on screen.
- Week 1: login, layout, and the first screens in fake mode.
- Week 2: the main screens complete; A makes endpoints live one by one and you switch
  those functions over.
- Week 3: testing with the real backend, fixes, README, demo. No new features.
- If time runs short, the first things we cut are: the map pin picker, reminders, and
  the extra head admin screens. The core flow (login, schedule, plan, publish, ride cards,
  trip list) is what must work.

## 12. When something goes wrong

- "Failed to resolve import X": run npm install inside frontend/. If X is a new library, npm install X.
- "command not found: npm": Node is not installed, or the terminal was opened before
  installing. Close and reopen the terminal.
- Blank white page: press F12, open Console, read the red error, send it to the team.
- Reloading shows the login page: your fake user is not saved, or the tab is on a
  different address. Paste the section 4 line again on localhost:5173, then reload.
- Port already in use: another npm run dev is still running. Close it, or use the port it prints.
- Git asks for a password: use the personal access token from section 2.
- "Your branch is behind": run git pull.
- You committed .env or node_modules by mistake: tell A before pushing. Do not push it.
