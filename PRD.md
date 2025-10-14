# MoveAI PRD

## Problem statement

It’s difficult to master new movements whether it’s a specific exercise (e.g., barbell back squat) or a new skill in sport (e.g., golf swing). Ideally you would have a coach or personal trainer showing you how to execute the movement, giving you mental cues, and providing real time feedback as you try it out. Unfortunately this is not feasible for everyone due to cost, time, or location constraints. This is problematic because learning new movements with improper technique can lead to:

1. Bad habits: We are creatures of habit. Once you learn how to do something, it’s very difficult to retrain (e.g., Lonzo Ball’s jump shot)  
2. Plateaus: It’s possible that learning a technique the wrong way may help you progress faster at first, but this often leads to plateaus in performance.  
3. Injury: Performing techniques wrong could lead to injuries from putting your body in positions where it is mechanically disadvantaged. This could be the result of a severe incident or from chronic misuse

## Product vision

MoveAI (final name pending availability) will provide personalized coaching for users that want to master a given movement or technique. This will help beginners learn faster and help elite athletes fine tune where needed. Users will simply record a video of themselves to get real time feedback that is customized to their goals and biomechanics. This will help users pursue their passions while promoting better health and longevity. 

## User personas

The core user personas are

1. Athletes: These users will have varying levels of experience and proficiency, but their primary goal is to perfect technique so that they can optimize performance in their sports. These are likely to be the super users that will return often to get feedback

2. Rehab patients: These users will have some existing difficulties with some mechanics because they are rehabbing an injury, recovering from surgery, or have built bad habits over time. They will be interested in postural correction to return to life pain free.

## Scope

The app will focus on techniques in sports, exercises for improving performance, and physical therapy. We will start with a narrow set of use cases where there is lots of data on what “good” looks like. Some logical first steps are power lifting exercises such as deadlift, squat, and bench where there are years of data on proper biomechanics. 

## CUJs

1. \[create-profile\] I want to quickly set up my profile and enter my goals so I can get personalized recommendations without friction, so I…  
   1. \[enter-info\] Enter relevant info like height, weight, other relevant information  
   2. \[sync-info\] There’s an option to sync this data from the health app   
   3. \[digitize\] Take pictures of myself so that the app can understand absolute and relative proportions as it pertains to proper technique

2. \[set-goals\] I want to specify which movements I want to master, so I…  
   1. \[browse\] Browse a menu of different movements organized by sport. For example, I might see “barbell squat” under “power lifting” or see “roundhouse kick” under “Muay Thai”  
   2. \[select\] Make a selection of the different movements

3. \[collect-data\] I want to provide examples of my current technique, so I…  
   1. \[upload-video\] Upload existing videos that I have   
      1. \[film-assist\] The app should let me know if the videos are clear enough to collect data points. They should let me know how I should adjust camera positioning for better videos.   
   2. \[take-video\] Open my camera to begin taking a new video.   
      1. \[film-assist\] The app should give the user realtime feedback on if the camera position is acceptable for the video. This will help the user set up the camera or help the person who’s filming

4. \[get-feedback\] I want to get feedback on the videos that I’ve uploaded, so I…  
   1. \[assess-position\] View my videos with key body positions highlighted as either correct or deviating from ideal. The app should have the assessments superimposed on the video and allow the user to scrub through time to see how positions changed  
      1. For example, the app should be able to see how upright my torso is throughout a back squat to ensure that I’m performing the exercise correctly  
   2. \[summarize-pointers\] The app should provide a summarized list of pointers for the video uploaded with the following  
      1. \[importance\] The app should also differentiate based on how important it is to fix. Some positions may be dangerous and severe if not corrected soon (e.g., rounded back on a deadlift) vs others which are more for optimizing performance.  
      2. \[mental-cues\] Each pointer should come with common mental cues that coaches use to help athletes maintain proper body position (e.g., head down during golf swing).  
      3. \[corrective-exercises\] Each pointer should have some supplementary exercises that the user can try to improve their position (e.g., if ankle mobility is limited in the back squat, the app should suggest exercise to improve range of motion)  
   3. \[score\] I want to see some overall “score” for my movement  
      1. This can be calculated as something like the MAPE between the user’s pose in each frame and the ideal

5. \[track-progress\] I want to track my progress for each movement over time, so I…  
   1. \[home\] Go to my home page that shows all my current movements I’m working on  
   2. \[view-progress\] Click on a given exercise and see   
      1. How my overall movement score is trending over time   
      2. Cues that I have mastered and what I still need to keep in mind   
   3. \[view-suggestions\] I want to see some suggestions to accelerate my progress based on my overall progress, trends, and history of errors. This would include:  
      1. Suggested training frequency for the technique  
      2. Exercises that break the technique down (e.g., A-skips for sprinting form)  
      3. Corrective exercises or stretches I can work into my weekly routine, 

## Requirements

| CUJ | Tasks | Requirement |
| :---- | :---- | :---- |
| create-profile | enter-info | It must be possible to enter my information into the app in a streamlined fashion |
| create-profile | sync-info | It must be possible to sync my information with the existing data on my phone |
| create-profile | digitize | It must be possible for the app to calculate proportions from user uploaded pictures |
| set-goals | browse | It must be possible to browse a menu of different movements organized by sports. They should have a logical grouping and categories to make the user experience easy |
| set-goals | select | It must be possible to select one or more goals to work on |
| collect-data | upload-video | It must be possible to access existing videos on my phone that are stored locally, in the cloud, on Instagram, or other apps |
| collect-data | upload-video:film-assist | It must be possible to assess the video and either validate that it captures everything that’s needed or make suggestions on how to improve the angles |
| collect-data | take-video | It must be possible to open the camera and film a video within the app |
| collect-data | take-video:film-assist | It must be possible for the app to offer real time feedback on camera angles and zoom so that the user can take a successful video on the first try. People sometimes have a limited amount of repetitions they execute and they don’t want to do extras because the camera wasn’t correct  |
| get-feedback | assess-position | It must be possible to extract joint coordinates from video frames. This can be done with existing open source libraries such as Google Gemini’s latest Pose-estimation algorithm that is part of their Media Pipe Open-Source code |
| get-feedback | assess-position | It must be possible to generate a baseline for “gold standard” form. This should be personalized to the user’s proportions.For example, the “ideal” squat will look different based on people’s proportions such as femur length vs total height |
| get-feedback | assess-position | It must be possible to do frame-by-frame comparison to compute positional error |
| get-feedback | assess-position | It must be possible for the user to move through each frame that was assessed as they watch the video |
| get-feedback | summarize-pointers | It must be possible to show a summary of the movement assessment |
| get-feedback | summarize-pointers: importance | It must be possible to understand the relative severity of different postural errors. This will be highly movement specific, but will be programmed over time as new movements are added. |
| get-feedback | summarize-pointers: mental-cues | It must be possible to translate postural errors to common mental cues to help the user correct their positioning  |
| get-feedback | summarize-pointers: corrective-exercises | It must be possible to translate postural errors to corrective exercises that can help address mobility limitations or get users comfortable in different positions |
| get-feedback | score | It must be possible to calculate an overall “goodness” score for the movement |
| track-progress | home | It must be possible to display a home page with an easy to understand summary of all the movements that the users are training. If there are many, this should be organized by sport or category |
| track-progress | view-progress | It must be possible to show users how their “goodness” score and cues are trending over time |
| track-progress | view-suggestions | It must be possible to analyze historical uploads for a given movement to produce suggestions on how to improve faster. Suggestions include training frequency and supplemental exercises |

## Success metrics

| Category | Metric |
| :---- | :---- |
| User experience | ≥ 90% video usability pass rate (clear capture, angle) |
| Model accuracy | Mean pose deviation error \< 10° for key joints |
| Engagement | ≥ 3 videos uploaded per week per active user |
| Retention | 30-day retention \> 50% |
| User value | 80% of users report “improved technique” after 2 weeks |

## Future work

* Integrate with wearables (Apple Watch, WHOOP) for dynamic metrics  
* Community leaderboards and “coach marketplace”  
* Custom training plans based on movement deficits

## Appendix

* [https://cdn.prod.website-files.com/64416928859cbdd1716d79ce/68da20c5d76f5727b6ae2c15\_Poppy\_PerfApp\_CheatSheet.pdf](https://cdn.prod.website-files.com/64416928859cbdd1716d79ce/68da20c5d76f5727b6ae2c15_Poppy_PerfApp_CheatSheet.pdf) 