// This script aims to recreate the Superheavy tower catch seen in Starbase on Starship flights 5, 7 and 8. It works about 50% of the time and needs a lot of improvement or even a complete rewrite to correct the questionable code I wrote. This is the third itteration of this script I've wrote and is the first to see the light of day.

set runmode to 1.

set internalTimer to 0.
set startTime to time:seconds.
set countdownTime to 30.
set towerAvoidanceStartTime to 0.
set fuelDepletedTime to 0.
set engineCheckLastTime to -10.
set boostBackShutdownTime to 0.
set landingBurnTenShutdownTime to 0.
set catchTime to 0.

set offshoreDivert to False. // Will activate if more than 2 engines out on boostback or if any of the 3 center engines are out.
set takeControlDuringStageSep to True.
set padLocation to ship:geoPosition.
set shipStartName to ship:name.
set startAltitude to alt:radar.

set raptorCenter to ship:partsdubbed("BoosterRC").
set raptorBoost to ship:partsdubbed("SEP.23.RAPTOR2.SL.RB").
set fuelCutoffPoint to 250000.
raptorCenter[0]:activate().
set raptorAvailableThrustTest to raptorCenter[0]:availableThrust.
raptorCenter[0]:shutdown().

if raptorAvailableThrustTest = 0 {
    set runmode to 0.
    print("Revert to launch and try again...").
}

set centerIgnition to False.
set boostBank1Ignition to False.
set boostBank2Ignition to False.
set liftoffThrottle to 0.001.
set liftoffThrottleUp to False.
set ignitionEngineCount to 0.
set ignitionCenterCount to 0.
set towerAvoidanceComplete to False.
set hotstagePitch to 0.
set boostbackIgnition to False.
set landingBurnIgnition to False.

set ascentTargetPitch to 90.
set ascentTargetRoll to facing:topvector:mag.
set landingAlt to 111. // Using "print alt:radar" while in the chopsticks. Its close enough to 111 that its perfectly fine to round.
set aoa to 30.
set maxAoa to 30.
set targetInc to 26.5. // 26.5 is the inclination Starship takes out of Boca. Slightly south to miss Florida.
set launchDirect to 1. // 0 is North, 1 is South
set testCorrectionPitch to 0. // For dual engine landings the horizontal speed gets too low so I'm trying things
set coastFlipPitch to 0.
set coastFlipStartVector to 0.

// MECO Things
set mecoEngineBanks to list(
    list(raptorBoost[0], raptorBoost[4], raptorBoost[8], raptorBoost[12], raptorBoost[16]),
    list(raptorBoost[2], raptorBoost[6], raptorBoost[10], raptorBoost[14], raptorBoost[18]),
    list(raptorBoost[1], raptorBoost[5], raptorBoost[9], raptorBoost[13], raptorBoost[17]),
    list(raptorBoost[3], raptorBoost[7], raptorBoost[11], raptorBoost[15], raptorBoost[19]),
    list(raptorCenter[3], raptorCenter[5], raptorCenter[7], raptorCenter[9], raptorCenter[11]),
    list(raptorCenter[4], raptorCenter[6], raptorCenter[8], raptorCenter[10], raptorCenter[12])
).
set mecoShutdownBankNo to 0.
set mecoLastShutdownTime to 0.

// Boostback Startup Things
set boostbackEngineBanks to list(
    list(raptorCenter[3], raptorCenter[8]),
    list(raptorCenter[5], raptorCenter[10]),
    list(raptorCenter[7], raptorCenter[12]),
    list(raptorCenter[9], raptorCenter[4]),
    list(raptorCenter[11], raptorCenter[6])
).
set boostbackStartupBankNo to 0.
set boostbackLastStartupTime to 0.

// Landing Startup Things
set landingBurnEngineBanks to list(
    list(raptorCenter[0], raptorCenter[1], raptorCenter[2]),
    list(raptorCenter[3], raptorCenter[5], raptorCenter[7], raptorCenter[9], raptorCenter[11]),
    list(raptorCenter[8], raptorCenter[10], raptorCenter[12], raptorCenter[4], raptorCenter[6])
).
set landingStartupBankNo to 0.
set landingLastStartupTime to 0.
set landingIgnitionInterval to 0.3.
set landingEngineMode to 0. // 0 is all 13, 1 is middle 3
set raptorAvailableThrust to 0.
set chopsticksPosition to ship:partsdubbed("SLE.SS.OLIT.MZ")[0]:position. // Mitigating an issue which could show up when the tower loads in during landing burn

until runmode = 0 {
    set internalTimer to time:seconds - startTime - countdownTime.
    printData().
    manageTowerConnection().
    manageShipConnection().
    if runmode = 1 {
        // DSS Activation
        if internalTimer >= -15 and not ship:partsdubbed("SLE.SS.OLM")[0]:ignition {
            ship:partsdubbed("SLE.SS.OLM")[0]:getModule("ModuleEnginesRF"):doEvent("activate engine").
        }
        // Waterpad Activation
        if internalTimer >= -10 and ship:partsdubbed("SLE.SS.SteelPlate"):length > 0 {
            if not ship:partsdubbed("SLE.SS.SteelPlate")[0]:ignition {
                ship:partsdubbed("SLE.SS.SteelPlate")[0]:getModule("ModuleEnginesRF"):doEvent("activate engine").
            }
        }
        // Center Engines Ignition
        if internalTimer >= (-2 - raptorCenter[0]:getModule("ModuleEnginesRF"):getField("effective spool-up time")) and not centerIgnition {
            for e in raptorCenter {
                if not e:ignition {
                    e:activate().
                }
            }
            lock throttle to 0.01.
            set centerIgnition to True.
        }
        // 15 Boost Engines Ignition
        if internalTimer >= (-1.5 - raptorBoost[0]:getModule("ModuleEnginesRF"):getField("effective spool-up time")) and not boostBank1Ignition {
            local boostFirstStartup is list(mecoEngineBanks[0], mecoEngineBanks[1], mecoEngineBanks[2]).
            for engineBank in boostFirstStartup {
                for e in engineBank {
                    if not e:ignition {
                        e:activate().
                    }
                }
            }
            set boostBank1Ignition to True.
        }
        // 5 Boost Engines Ignition
        if internalTimer >= (-1.25 - raptorBoost[0]:getModule("ModuleEnginesRF"):getField("effective spool-up time")) and not boostBank2Ignition {
            for e in mecoEngineBanks[3] {
                if not e:ignition {
                    e:activate().
                }
            }
            set boostBank2Ignition to True.
        }
        // Launch
        if internalTimer >= 0 {
            if ship:partsdubbed("SLE.SS.OLIT.SQD")[0]:getModule("ModuleSLESequentialAnimate"):hasEvent("full retraction") {
                ship:partsdubbed("SLE.SS.OLIT.SQD")[0]:getModule("ModuleSLESequentialAnimate"):doEvent("full retraction").
            }
            set runmode to 2.
        }
    }
    if runmode = 2 {
        // Steering
        set steeringManager:maxstoppingtime to 0.5.
        set steeringManager:rolltorquefactor to 24.
        if not towerAvoidanceComplete {
            if alt:radar >= startAltitude + 8 and towerAvoidanceStartTime = 0 {
                set ascentTargetPitch to 88.
                set towerAvoidanceStartTime to internalTimer.
                lock steering to heading(90, ascentTargetPitch, 0).
            }
            if not towerAvoidanceStartTime = 0 and internalTimer >= towerAvoidanceStartTime + 5 {
                set ascentTargetPitch to 90.
                set towerAvoidanceComplete to True.
            }
        }
        if alt:Radar >= 500 {
            // Target pitch code from https://youtu.be/tnZ8Jlc6Zsc & https://www.dropbox.com/scl/fi/k7mnwvcw2mmc00bplmyb9/shuttles.txt?rlkey=4b3w99g15ejdkxmmlqxcmhoi5&e=1&dl=0
            set ascentTargetPitch to max(90 * (1 - (alt:radar / 75000) ^ (1 - (0.45 / 2.5))), 30). // 0.45 - Smaller number results in a steeper trajectory
            set ascentTargetRoll to -90.
            if fuelCutoffDetection(fuelCutoffPoint + 15000) { // Aligning to velocity vector for stage sep
                set ascentTargetPitch to vectorPitch(srfPrograde:vector).
            }
            lock steering to heading(azimuthCalc(), ascentTargetPitch, ascentTargetRoll).
        }
        rcsCommand(False).
        gridfinCommand(False, False).
        // Throttle Up
        local limitQThrottle is 1.
        local afterQThrottle is 1.
        if getTWR() <= 1.44 and not liftoffThrottleUp { // Need to tweak more so this number can be 1.50
            set liftoffThrottle to min(1, throttle + 0.03).
            if throttle = 1 {
                set liftoffThrottleUp to True.
            }
        }
        if ship:q * constant:atmtokpa >= 15 { // Stops this from being active for the entire flight
            set qPID to pidLoop(1.15, 0.01, 0.5, 0.01, 1).
            set qPID:setpoint to 20.
            set limitQThrottle to min(max(qPID:update(time:seconds, ship:q * constant:atmTokPa), 0.001), 1).
        }
        if internalTimer > 60 { // TODO - Implement throttle to Q into the script and start this on throttle back up
            set afterQThrottle to setTargetThrust((raptorAvailableThrustTest * 33) * 0.8).
        }
        lock throttle to min(liftoffThrottle, min(limitQThrottle, afterQThrottle)).
        // Fuel Level Cutoff
        if fuelCutoffDetection(fuelCutoffPoint) {
            set fuelDepletedTime to internalTimer.
            gridfinCommand(False, True).
            set runmode to 3.
        }
        // Engine counting - Every second to not cause performance issues
        if internalTimer >= engineCheckLastTime + 1 {
            local localEngineCount is 0.
            for e in raptorCenter {
                if e:ignition {
                    set localEngineCount to localEngineCount + 1.
                    // 5 degrees of gimbal for the way up
                    if e:getModule("ModuleGimbal"):getField("gimbal limit") <> 33.3 { // 5 degrees gimbal range
                        e:getModule("ModuleGimbal"):setField("gimbal limit", 33.3).
                    }
                }
            }
            for e in raptorBoost {
                if e:ignition {
                    set localEngineCount to localEngineCount + 1.
                }
            }
            set engineCheckLastTime to internalTimer.
            set ignitionEngineCount to localEngineCount.
            for e in raptorCenter:sublist(0, 3) {
                if e:ignition {
                    set ignitionCenterCount to ignitionCenterCount + 1.
                }
            }
        }
        // Liftoff Command
        if ship:partsdubbed("SLE.SS.OLM"):length > 0 {
            if ignitionEngineCount >= 30 and ignitionCenterCount >= 2 {
                if getTWR() >= 1.0 {
                    if ship:partsdubbed("SLE.SS.OLM")[0]:getModule("ModuleAnimateGeneric"):hasEvent("close clamps + qd") {
                        ship:partsdubbed("SLE.SS.OLM")[0]:getModule("ModuleAnimateGeneric"):doEvent("close clamps + qd").
                    }
                    ship:partsdubbed("SLE.SS.OLM")[0]:getModule("LaunchClamp"):doEvent("release clamp").
                    lock steering to lookDirUp(up:vector, facing:topvector).
                }
            } else {
                // Launch abort code here.
                lock throttle to 0.
                for e in raptorBoost {
                    if e:ignition {
                        e:shutdown().
                    }
                }
                for e in raptorCenter {
                    if e:ignition {
                        e:shutdown().
                    }
                }
                set runmode to 0.
            }
        }
    }
    if runmode = 3 {
        // Throttle down for stage sep - TODO: Sort this out
        local setThrottle is throttle.
        if internalTimer <= fuelDepletedTime + 4.8 {
            set setThrottle to max(setThrottle - 0.03, 0.33).
        } else if internalTimer > fuelDepletedTime + 4.8 { // MECO should be complete by this time
            set setThrottle to setTargetThrust((raptorAvailableThrustTest * 3) * 0.625).
        }
        lock throttle to setThrottle.
        // MECO logic
        if internalTimer >= fuelDepletedTime + 3 {
            if mecoShutdownBankNo <= 5 {
                if internalTimer >= mecoLastShutdownTime + 0.15 {
                    for e in mecoEngineBanks[mecoShutdownBankNo] {
                        if e:ignition {
                            e:shutdown().
                        }
                    }
                    set mecoLastShutdownTime to internalTimer.
                    set mecoShutdownBankNo to min(mecoShutdownBankNo + 1, mecoEngineBanks:length).
                }
            }
        }
        if hotstagePitch = 0 {
            set hotstagePitch to vectorPitch(srfPrograde:vector).
        }
        // Take control on booster & separate ship
        if ship:partsdubbed("SEP.23.RAPTOR.VAC"):length > 0 and internalTimer >= fuelDepletedTime + (8 - ship:partsdubbed("SEP.23.RAPTOR.VAC")[0]:getModule("ModuleEnginesRF"):getField("effective spool-up time")) {
            if takeControlDuringStageSep and ship:partsdubbed("SEP.25.BOOSTER.CORE")[0]:getModule("ModuleCommand"):hasEvent("control from here") {
                ship:partsdubbed("SEP.25.BOOSTER.CORE")[0]:getModule("ModuleCommand"):doEvent("control from here").
            }
            if ship:partsdubbed("SEP.25.BOOSTER.HSR")[0]:getModule("ModuleDecouple"):hasEvent("decouple") {
                ship:partsdubbed("SEP.25.BOOSTER.HSR")[0]:getModule("ModuleDecouple"):doEvent("decouple").
            }
        }
        // Start flip manually. SEP booster doesn't get pushed back a great deal from hotstaging so this is needed
        if internalTimer >= fuelDepletedTime + 8 {
            lock steering to heading(azimuthCalc() - 180, 0, 180).
            set steeringManager:maxstoppingtime to 2.
            set steeringManager:rolltorquefactor to 6.
            set runmode to 4.
        }
    }
    if runmode = 4 {
        // Enable engines if booster is facing more than 25 degrees away from separation attitude
        if vang(heading(azimuthCalc(), 20):vector, ship:facing:vector) > 25 and not boostbackIgnition {
            if boostbackStartupBankNo <= 4 {
                if  internalTimer >= boostbackLastStartupTime + 0.3 {
                    for e in boostbackEngineBanks[boostbackStartupBankNo] {
                        if not e:ignition {
                            e:activate().
                        }
                    }
                    set boostbackLastStartupTime to internalTimer.
                    set boostbackStartupBankNo to min(boostbackStartupBankNo + 1, boostbackEngineBanks:length).
                }
            } else {
                set boostbackIgnition to True.
            }
            set steeringManager:maxstoppingtime to 0.5.
            gridfinCommand(False, False).
        }
        local distance is (addons:tr:impactpos:position - padLocation:position):mag / 1000.
        // Engine out checks - Offshore divert if any of the 3 center or more than 2 of the middle ring engines are out. Check once every second to not cause performance issues.
        if internalTimer >= engineCheckLastTime + 1 {
            for e in raptorBoost {
                if e:ignition {
                    e:shutdown().
                }
            }
            local enginesRunning is 0.
            local centerRunning is 0.
            for e in raptorCenter {
                if raptorCenter:sublist(0, 3):contains(e) {
                    if e:ignition {
                        set centerRunning to centerRunning + 1.
                    } else {
                        if e:getModule("ModuleGimbal"):getField("gimbal limit") <> 70 {
                            e:getModule("ModuleGimbal"):setField("gimbal limit", 70).
                        }
                    }
                }
                if e:ignition {
                    set enginesRunning to enginesRunning + 1.
                    if raptorCenter:sublist(3, 10):contains(e) and e:getModule("ModuleGimbal"):getField("gimbal limit") <> 40 {
                        e:getModule("ModuleGimbal"):setField("gimbal limit", 40).
                    }
                }
            }
            if (enginesRunning < 11 and boostbackIgnition and distance > 40) or (centerRunning < 2) {
                set offshoreDivert to True.
            }
            if ship:thrust > 200 {
                set raptorAvailableThrust to ship:availablethrust / enginesRunning.
            }
            set engineCheckLastTime to internalTimer.
        }
        // Rest of boostback when booster is within 25 degrees of boostback attitude
        if vang(heading(90 - arcTan2(padLocation:lat - addons:tr:impactpos:lat, padLocation:lng - addons:tr:impactpos:lng), 0):vector, ship:facing:vector) < 25 {
            local thrustTarget is (raptorAvailableThrustTest * 13) * 0.8.
            // Steering
            lock steering to heading(90 - arcTan2(padLocation:lat - addons:tr:impactpos:lat, padLocation:lng - addons:tr:impactpos:lng), 0, 180).
            rcsCommand(False).
            gridfinCommand(False, False).

            // Down to 3 engines
            if distance <= 40 {
                for e in raptorCenter:sublist(3, 10) {
                    if e:ignition {
                        e:shutdown().
                    }
                }
                set thrustTarget to (raptorAvailableThrustTest * 3) * 0.8.
            }
            if distance <= 15 {
                lock steering to lookDirUp(facing:vector, facing:topvector).
            }
            // Shutdown
            if distance <= 6 or (offshoreDivert and distance <= 30) {
                lock throttle to 0.
                for e in raptorCenter {
                    if e:ignition {
                        e:shutdown().
                    }
                }
                set boostBackShutdownTime to internalTimer.
                unlock steering.
                set runmode to 5.
            }
            // Throttle to maintain specific thrust to allow for engines out. TODO - Move to a PID for better control. This is good enough for now.
            local newThrottleSetting is setTargetThrust(thrustTarget).
            lock throttle to newThrottleSetting.
        }
    }
    if runmode = 5 {
        // Coast Flip
        if coastFlipStartVector = 0 {
            set coastFlipStartVector to facing:vector.
        }
        if coastFlipPitch = 0 {
            set coastFlipPitch to vectorPitch(coastFlipStartVector).
        }
        local pitchIncrement is 0.1.
        // Steering
        if vAng(srfRetrograde:vector, ship:facing:vector) <= 30 {
            lock steering to correctSteering().
        } else {
            if internalTimer >= boostBackShutdownTime + 4 {
                set coastFlipPitch to coastFlipPitch + pitchIncrement.
            }
            lock steering to heading(vectorHeading(coastFlipStartVector), coastFlipPitch, 180).
        }
        rcsCommand(True).
        gridfinCommand(False, False).
        lock throttle to 0.
        // HSR jettison
        if internalTimer >= boostBackShutdownTime + 2 and ship:partsdubbed("SEP.25.BOOSTER.HSR"):length > 0 {
            if ship:partsdubbed("SEP.25.BOOSTER.CORE")[0]:getModule("ModuleDecouple"):hasEvent("decouple") {
                ship:partsdubbed("SEP.25.BOOSTER.CORE")[0]:getModule("ModuleDecouple"):doEvent("decouple").
            }
        }
        // Landing mode under 50km
        if altitude <= 50000 {
            set runmode to 6.
        }
    }
    if runmode = 6 {
        // Landing Burn Shutdown
        if verticalSpeed >= -0.5 {
            set catchTime to internalTimer.
            set runmode to 7.
        }
        // Landing
        local newLandingAlt is landingAlt + 300.
        local extraThrottle is 0.05.
        // Configure RCS and the grid fins
        rcsCommand(False).
        // Engine Control
        local enginesRunning is 0.
        local centerRunning is 0.
        for e in raptorCenter {
            if e:ignition {
                set enginesRunning to enginesRunning + 1.
                if raptorCenter:sublist(3, 10):contains(e) and e:getModule("ModuleGimbal"):getField("gimbal limit") <> 40 {
                    e:getModule("ModuleGimbal"):setField("gimbal limit", 40).
                }
            }
            if raptorCenter:sublist(0, 3):contains(e) {
                if e:ignition {
                    set centerRunning to centerRunning + 1.
                    if e:getModule("ModuleGimbal"):getField("gimbal limit") <> 70 {
                        e:getModule("ModuleGimbal"):setField("gimbal limit", 70).
                    }
                }
            }
            // Shutdown the middle ring if the engine mode is 1.
            if landingEngineMode = 1 {
                if raptorCenter:sublist(3, 10):contains(e) {
                    if e:ignition {
                        e:shutdown().
                    }
                }
                set extraThrottle to (vang(up:vector, ship:facing:vector) / 100) + 0.065.
                if (ship:geoPosition:position - padLocation:position):mag <= 10 { // Remove the extra throttle if less than 10 meters from landing point
                    set extraThrottle to 0.025.
                }
                set newLandingAlt to landingAlt.
            } 
        }
        if ship:thrust > 200 {
            set raptorAvailableThrust to ship:availablethrust / enginesRunning.
        } else {
            set enginesRunning to 13.
            set centerRunning to 3.
        }
        // Landing Throttle Calculations - Calculating both 3 and 13 engine throttle so the landing can move to 3 engines at the right time
        lock trueRadar to alt:radar - newLandingAlt.
        lock g to constant:g * body:mass / body:radius ^ 2.

        lock fullEngineDecel to ((raptorAvailableThrust * enginesRunning) / ship:mass) - g.
        lock finalEngineDecel to ((raptorAvailableThrust * centerRunning) / ship:mass) - g.

        lock thirteenEngineStopDist to ship:verticalspeed ^ 2 / (2 * fullEngineDecel).
        lock threeEngineStopDist to ship:verticalspeed ^ 2 / (2 * finalEngineDecel).

        local stopDist is thirteenEngineStopDist.
        if ((threeEngineStopDist / trueRadar) < (thirteenEngineStopDist / trueRadar) + 0.8 and throttle > 0 and velocity:surface:mag < 100) or landingEngineMode = 1 {
            set stopDist to threeEngineStopDist.
            if landingBurnTenShutdownTime = 0 { set landingBurnTenShutdownTime to internalTimer. }
            gridfinCommand(False, False).
            set landingEngineMode to 1.
        } else {
            gridfinCommand(True, False).
        }
        // Landing Throttle Set
        if trueRadar <= stopDist + 1500 {
            lock throttle to min(max((stopDist / trueRadar) + extraThrottle, 0.001), 1).
        }
        // Landing Burn Ignition - Staggered ignition just like the real landing burn
        if throttle > 0 and not landingBurnIgnition {
            if landingStartupBankNo <= landingBurnEngineBanks:length - 1 {
                if internalTimer >= landingLastStartupTime + landingIgnitionInterval {
                    for e in landingBurnEngineBanks[landingStartupBankNo] {
                        if not e:ignition {
                            e:activate().
                        }
                    }
                    if landingBurnEngineBanks[landingStartupBankNo] = landingBurnEngineBanks[1] {
                        set landingIgnitionInterval to 1.
                    }
                    set landingLastStartupTime to internalTimer.
                    set landingStartupBankNo to min(landingStartupBankNo + 1, landingBurnEngineBanks:length).
                }
            } else {
                set landingBurnIgnition to True.
            }
        }
        // Shutdown any Raptor boost engines if they are active. Checking every second to not impact performance or give enough time for ignition.
        if internalTimer >= engineCheckLastTime + 1 {
            for e in raptorBoost {
                if e:ignition {
                    e:shutdown().
                }
            }
            set engineCheckLastTime to internalTimer.
        }
        // Steering
        set steeringManager:rolltorquefactor to 1.
        set steeringManager:yawtorquefactor to 0.65.
        set steeringManager:yawts to 1.
        if not offshoreDivert { // Tower Catch
            // Reentry - No Engines
            if landingEngineMode = 0 and ship:thrust = 0 {
                set steeringManager:pitchpid:kp to 0.5.
                set aoa to min(maxAoa * min(((addons:tr:impactpos:position - padLocation:position):mag / 1000) * 10, 1), maxAoa).
                lock steering to correctSteering().
            }
            // 13 Engine Landing
            if landingEngineMode = 0 and ship:thrust > 300 {
                set steeringManager:maxstoppingtime to 0.1.
                steeringManager:resetpids().
                set aoa to -min(maxAoa * min(((addons:tr:impactpos:position - padLocation:position):mag / 1000) * 10, 1), maxAoa).
                if ship:groundspeed < 30 {
                    set testCorrectionPitch to testCorrectionPitch + 1.
                }
                lock steering to heading(vectorHeading(correctSteering()), max(vectorPitch(correctSteering()), 67.5) + testCorrectionPitch, 0).
            }
            // 3 Engine Landing
            if landingEngineMode = 1 and internalTimer > landingBurnTenShutdownTime + 1 and runmode = 6 {
                // Source for this part of the code https://youtu.be/Kl7qquLeSIc & https://pastebin.com/pfMHF0zQ
                set steeringManager:maxstoppingtime to 5.
                set VTgt to heading(padLocation:heading, 0):vector * vdot(heading(padLocation:heading, 0):vector, ship:velocity:surface). // Current velocity towards target
                set DTgt to vdot(heading(padLocation:heading, 0):vector, padLocation:position). // Current distance to target
                set VReq to min(DTgt / 5, 20) * heading(padLocation:heading, 0):vector. // Required velocity towards target, distance/5 with upper limit
                If dTgt > 3 {
                    set ATgtReqUL to (vReq - vTgt) / 3.
                } else {
                    set ATgtReqUL to (vReq - vTgt) / 2. 
                }
	            set ATgtReq to ATgtReqUL:normalized * min(min(ATgtReqUL:mag, 9.81), sqrt(max((ship:thrust / ship:mass) ^ 2 - 9.81, 0.0001) ^ 2)).
                set vSide to ship:velocity:surface - VTgt - ship:up:vector * vdot(ship:up:vector, ship:velocity:surface).
                set ASideReq to -vSide / 3. // Side acceleration required to cancel drift in 3 seconds
                set AccVec to ATgtReq + ASideReq - ship:sensors:grav.
                lock steering to lookdirup(AccVec, chopsticksPosition).
            }
        } else { // Offshore Divert
            local targetExtraPitch is -20.
            if ship:thrust > 200 and (geoPosition:position - padLocation:position):mag / 1000 > 10 {
                set targetExtraPitch to 0.
            }
            lock steering to lookDirUp(heading(vectorHeading(srfRetrograde:vector), vectorPitch(srfRetrograde:vector) + targetExtraPitch):vector, chopsticksPosition).
        }
        // Point directly up if the booster is within 15m of the target if it's not offshore, under 120m agl and moving slower than 2m/s horizontally
        if ((geoPosition:position - padLocation:position):mag / 1000 < 0.015 or offshoreDivert) and alt:radar < (landingAlt + 25) and ship:groundspeed < 4 {
            lock steering to lookDirUp(up:vector, chopsticksPosition).
        }
    }
    if runmode = 7 {
        // TODO - Vent tanks after shutdown
        if (ship:angularVel:y > 0.01 or ship:angularVel:y < -0.01) or vAng(facing:vector, up:vector) > 2.5 {
            lock throttle to 0.05.
            lock steering to lookDirUp(up:vector, chopsticksPosition).
        } else {
            unlock steering.
            lock throttle to 0.    
            if internalTimer >= engineCheckLastTime + 1 {
                for e in raptorCenter {
                    if e:ignition {
                        e:shutdown().
                    }
                }
                for e in raptorBoost {
                    if e:ignition {
                        e:shutdown().
                    }
                }
                set engineCheckLastTime to internalTimer.
            }
        }
        rcs off.
        if internalTimer >= catchTime + 10 {
            set runmode to 0.
            clearscreen.
            print(":)").
        }
    }
    wait 0.
}

function printData {
    clearscreen.
    print("----- Superheavy Data -----") at(0, 0).
    print("Flight Time: " + round(internalTimer, 2)) at(0, 1).
    print("Flight Mode: " + runmode) at(0, 2).
    print("Offshore Divert: " + offshoreDivert) at(0, 3).

    print("Surface Speed: " + round(velocity:surface:mag, 2) + " m/s") at(0, 5).
    print("Altitude ASL: " + round(altitude / 1000, 2) + " km") at(0, 6).
    print("Downrange Dist: " + round((geoPosition:position - padLocation:position):mag / 1000, 2) + " km") at(0, 7).

    print("Dynamic Pressure: " + round(ship:q * constant:atmtokpa, 2)) at(0, 9).
    print("Vehicle Thrust: " + round(ship:thrust, 2)) at(0, 10).
    print("Thrust to Weight: " + round(getTWR(), 2)) at(0, 11).
    print("Throttle: " + round(throttle * 100, 2) + " %") at(0, 12).

    print("CH4 Level: " + round(fuelCutoffDetection(1), 2) + " %") at(0, 14).
    print("LOX Level: " + round(fuelCutoffDetection(2), 2) + " %") at(0, 15).

    print("Tower Connection: " + manageTowerConnection["Connected"]) at(0, 17).
    print("Tower CPU: " + manageTowerConnection["Destination"]:name) at(0, 18).
    print("Tower Loaded: " + manageTowerConnection["Loaded"]) at(0, 19).
}

function getTWR {
    local vehicleMass is ship:mass.
    if ship:partsdubbed("SLE.SS.OLM"):length > 0 {
        set vehicleMass to vehicleMass - 6160.058. // 6160.058 is the mass of the launch mount, tower and chopsticks in the VAB.
    }
    local TWR is ship:thrust / (vehicleMass * 9.81).
    return TWR.
}

function azimuthCalc { // Same source as the target pitch code
    local launchAzimuth is 0.
    if targetInc > ship:orbit:inclination {
        if launchDirect = 0 {
            set launchAzimuth to arcSin(cos(targetInc) / cos(ship:orbit:inclination)).
        }
        if launchDirect = 1 {
            set launchAzimuth to 180 - arcSin(cos(targetInc) / cos(ship:orbit:inclination)).
        }
    }
    if targetInc < ship:orbit:inclination {
        set launchAzimuth to 90.
    }
    return launchAzimuth.
}

function setTargetThrust { // Awful. Just awful... I wanted to use a PID but I couldn't work it out...
    parameter targetThrust.

    local increment is 0.005.
    local newThrottle is throttle.
    if ship:thrust > targetThrust {
        set newThrottle to newThrottle - increment.
    } else if ship:thrust < targetThrust {
        set newThrottle to newThrottle + increment.
    }
    return min(max(newThrottle, 0.0001), 1).
}

function fuelCutoffDetection { // Mode 1 - Return True when cutoff point is met. Mode 2 - Return percent of LH2. Mode 3 - Return percent of LOX.
    parameter cutoffAmount.

    local ch4Am is 0.
    local ch4Cap is 0.
    local loxAm is 0.
    local loxCap is 0.

    for resource in ship:partsdubbed("SEP.25.BOOSTER.CORE")[0]:resources {
        if resource:name = "CooledLqdMethane" {
            set ch4Am to resource:amount.
            set ch4Cap to resource:capacity.
        } else if resource:name = "CooledLqdOxygen" {
            set loxAm to resource:amount.
            set loxCap to resource:capacity.
        }
    }
    local cutoffPercent is cutoffAmount / ch4Cap.

    if cutoffAmount = 1 { return (ch4Am / ch4Cap) * 100. }
    if cutoffAmount = 2 { return (loxAm / loxCap) * 100. }

    if (ch4Am / ch4Cap) <= cutoffPercent or (loxAm / loxCap) <= cutoffPercent {
        return True.
    }
}

function rcsCommand {
    parameter rcsEnabled.
    ship:partsdubbed("SEP.25.BOOSTER.CORE")[0]:getModule("ModuleRCSFX"):setField("rcs", rcsEnabled).
    set rcs to rcsEnabled.
}

function gridfinCommand {
    parameter steeringEnabled, hotstaging.
    for fin in ship:partsdubbed("SEP.25.BOOSTER.GRIDFIN") {
        if steeringEnabled {
            if fin:getModule("SyncModuleControlSurface"):hasAction("activate all controls") {
                fin:getModule("SyncModuleControlSurface"):doAction("activate all controls", True).
            }
            if fin:getModule("SyncModuleControlSurface"):getField("authority limiter") <> 40 {
                fin:getModule("SyncModuleControlSurface"):setField("authority limiter", 40).
            }
        } else {
            if fin:getModule("SyncModuleControlSurface"):hasAction("deactivate all controls") {
                fin:getModule("SyncModuleControlSurface"):doAction("deactivate all controls", True).
            }
        }
        if hotstaging {
            local otherFins is list(ship:partsdubbed("SEP.25.BOOSTER.GRIDFIN")[1], ship:partsdubbed("SEP.25.BOOSTER.GRIDFIN")[2]).
            if otherFins:contains(fin) {
                fin:getModule("SyncModuleControlSurface"):setField("deploy", True).
                fin:getModule("SyncModuleControlSurface"):setField("deploy direction", True).
            } else {
                fin:getModule("SyncModuleControlSurface"):setField("deploy", True).
                fin:getModule("SyncModuleControlSurface"):setField("deploy direction", False).
            }
        } else {
            if fin:getModule("SyncModuleControlSurface"):getField("deploy") {
                fin:getModule("SyncModuleControlSurface"):setField("deploy", False).
            }
        }
    }
}

function vectorHeading {
    parameter vecT.

    local east is vCrs(ship:up:vector, ship:north:vector).
    local trigX is vDot(ship:north:vector, vecT).
    local trigY is vDot(east, vecT).
    local result is arcTan2(trigY, trigX).

    if result < 0 {
        return 360 + result.
    } else {
        return result.
    }
}

function vectorPitch {
    parameter vecT.
    return 90 - vAng(ship:up:vector, vecT).
}

function correctSteering {
    local errorVector is addons:tr:impactpos:position - padLocation:position.
    local result is -ship:velocity:surface + errorVector.
    set result to -ship:velocity:surface:normalized + tan(aoa) * errorVector:normalized.
    return lookDirUp(result, up:forevector):vector.
}

function manageTowerConnection {
    if ship:partsdubbed("SLE.SS.OLM"):length = 0 {
        local tower is vessel(shipStartName + " Base").
        local towerCon is tower:connection.
        towerCon:sendmessage(lex("NameOfShip", shipStartName, "SaveTime", time:seconds, "GeoPos", ship:geoposition, "Alt", alt:radar, "Thrust", ship:thrust, "OriginPoint", padLocation)).
        return lex("Connected", towerCon:isConnected, "Destination", towerCon:destination, "Loaded", tower:loaded).
    } else {
        return lex("Connected", True, "Destination", ship, "Loaded", True). // Fake info but means I can keep connection info in console at all times
    }
}

function manageShipConnection {
    if ship:partsdubbed("SEP.24.SHIP.CORE"):length = 0 and internalTimer >= fuelDepletedTime + 8 and internalTimer <= fuelDepletedTime + 15 { // I don't know why I need to wait here when I don't for the tower... Just waiting until the ship starts to accelerate away to start communicating. Also only needed for hot-staging
        local starship is vessel(shipStartName + " Ship").
        local shipCon is starship:connection.
        shipCon:sendmessage(lex("CurrentPitch", hotstagePitch, "TargetInc", targetInc, "LaunchDirect", launchDirect, "Thrust", ship:thrust)).
    }
}
