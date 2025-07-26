// This script in it's current state is simply to get through hotstaging and nothing else. I put this together quickly so I could focus on the booster catch. I recommend putting this in the boot folder and setting it to auto run on the ship.

clearscreen.

set runmode to 1.

set internalTimer to 0.
set startTime to time:seconds.
set padLocation to ship:geoposition.
set separationDetectTime to 0.
set engineCheckLastTime to 0.

set raptorSeaLevel to ship:partsdubbed("ShipRC").
set raptorVacuum to ship:partsdubbed("SEP.23.RAPTOR.VAC").

set targetAp to 214.
set targetPe to -50.
// set targetInsertionAlt to 140.

set hotstageSeparation to False.
set raptorVacIgnition to False.
set raptorSeaLevelIgnition to False.

// Data From Booster. Change This Data In Booster Script - Booster pitch at hotstaging, target inc, launch direct, thrust
set boosterPitch to 0.
set targetInc to 0.
set launchDirect to 0.
set boosterThrust to 0.

until runmode = 0 {
    set internalTimer to time:seconds - startTime.
    printData().
    manageIncomingMessages().
    if runmode = 1 {
        if (throttle * 100) > 1 { // T-0 Detection
            set startTime to time:seconds.
        }
        if ship:partsdubbed("SEP.25.BOOSTER.CORE"):length = 0 and ship:partsdubbed("SEP.24.BOOSTER.INTEGRATED"):length = 0 { // Stage Sep Detection
            set hotstageSeparation to True.
            set separationDetectTime to internalTimer.
            set runmode to 2.
        }
    }
    if runmode = 2 { // Hotstage & Start of Burn
        if internalTimer >= engineCheckLastTime + 1 {
            if not raptorVacIgnition {
                for e in raptorVacuum {
                    if not e:ignition {
                        e:activate().
                    }
                }
            }
            if internalTimer >= separationDetectTime + (3 - raptorSeaLevel[0]:getModule("ModuleEnginesRF"):getField("effective spool-up time")) {
                for e in raptorSeaLevel {
                    if not raptorSeaLevelIgnition {
                        if not e:ignition {
                            e:activate().
                            if e = raptorSeaLevel[raptorSeaLevel:length - 1] {
                                set raptorSeaLevelIgnition to True.
                            }
                        }
                    }
                    local actuateOut is False.
                    if internalTimer <= separationDetectTime + 5 {
                        set actuateOut to True.
                    }
                    if not e:getModule("ModuleSEPRaptor"):getField("actuate out") = actuateOut {
                        e:getModule("ModuleSEPRaptor"):setField("actuate out", actuateOut).
                    }
                }
            }
            set engineCheckLastTime to internalTimer.
        }
        if internalTimer >= (separationDetectTime + raptorVacuum[0]:getModule("ModuleEnginesRF"):getField("effective spool-up time")) + 4 {
            local setThrottle is throttle.
            lock throttle to min(setThrottle + 0.05, 1).
            // Start steering here
        } else {
            local newThrust is setTargetThrust(boosterThrust * 1.5).
            lock throttle to newThrust.
            lock steering to heading(azimuthCalc, boosterPitch, -90).
        }
    }
    wait 0.
}

function manageIncomingMessages {
    local boosterMsgs is ship:messages.
    if boosterMsgs:length > 0 {
        local boosterNewMsg is boosterMsgs:pop.
        set boosterPitch to boosterNewMsg:content["CurrentPitch"].
        set targetInc to boosterNewMsg:content["TargetInc"].
        set launchDirect to boosterNewMsg:content["LaunchDirect"].
        set boosterThrust to boosterNewMsg:content["Thrust"].
        boosterMsgs:clear.
    }
}

function printData {
    clearscreen.
    print("----- Starship Data -----") at(0, 0).
    print("Flight Time: " + round(internalTimer, 2)) at(0, 1).
    print("Flight Mode: " + runmode) at(0, 2).
    print("Hotstage Sep: " + hotstageSeparation) at(0, 3).

    print("Surface Speed: " + round(velocity:surface:mag, 2) + " m/s") at(0, 5).
    print("Altitude ASL: " + round(altitude / 1000, 2) + " km") at(0, 6).
    print("Downrange Dist: " + round((geoPosition:position - padLocation:position):mag / 1000, 2) + " km") at(0, 7).

    print("Vehicle Thrust: " + round(ship:thrust, 2)) at(0, 9).
    print("Thrust to Weight: " + round(getTWR(), 2)) at(0, 10).
    print("Throttle: " + round(throttle * 100, 2) + " %") at(0, 11).

    print("CH4 Level: " + round(fuelLevelDetection(1), 2) + " %") at(0, 13).
    print("LOX Level: " + round(fuelLevelDetection(2), 2) + " %") at(0, 14).

    print("----- Current Orbit -----") at(0, 16).
    print("Apogee: " + round(apoapsis / 1000, 2) + " km") at(0, 17).
    print("Perigee: " + round(periapsis / 1000, 2) + " km") at(0, 18).
    print("Inclination: " + round(orbit:inclination, 2) + "°") at(0, 19).

    print("----- Target Orbit -----") at(0, 21).
    print("Target Ap: " + round(targetAp, 2) + " km") at(0, 22).
    print("Target Pe: " + round(targetPe, 2) + " km") at(0, 23).
    print("Target Inc: " + round(targetInc, 2) + "°") at(0, 24).

    // print("Booster Connection: " + manageTowerConnection["Connected"]) at(0, 16).
    // print("Booster CPU: " + manageTowerConnection["Destination"]:name) at(0, 17).
    // print("Booster Loaded: " + manageTowerConnection["Loaded"]) at(0, 18).
}

function getTWR {
    local vehicleMass is ship:mass.
    if ship:partsdubbed("SLE.SS.OLM"):length > 0 {
        set vehicleMass to vehicleMass - 6160.058. // 6160.058 is the mass of the launch mount, tower and chopsticks in the VAB.
    }
    local TWR is ship:thrust / (vehicleMass * 9.81).
    return TWR.
}

function azimuthCalc {
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

function fuelLevelDetection { // Mode 1 - Return True when cutoff point is met. Mode 2 - Return percent of LH2. Mode 3 - Return percent of LOX.
    parameter mode.

    local ch4Amount is 0.
    local ch4Capacity is 0.
    local loxAmount is 0.
    local loxCapacity is 0.

    for resource in ship:partsdubbed("SEP.24.SHIP.CORE")[0]:resources {
        if resource:name = "CooledLqdMethane" {
            set ch4Amount to resource:amount.
            set ch4Capacity to resource:capacity.
        } else if resource:name = "CooledLqdOxygen" {
            set loxAmount to resource:amount.
            set loxCapacity to resource:capacity.
        }
    }

    if mode = 1 { return (ch4Amount / ch4Capacity) * 100. }
    if mode = 2 { return (loxAmount / loxCapacity) * 100. }
}

function setTargetThrust {
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