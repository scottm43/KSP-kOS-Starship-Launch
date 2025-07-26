// This script automates the tower catch process of a Starship launch. I recommend putting this in the boot folder and setting it to auto run on the tower base.

clearscreen.

set runmode to 1.
if ship:partsdubbed("SEP.25.BOOSTER.CORE"):length = 0 and ship:partsdubbed("SEP.23.BOOSTER.INTEGRATED"):length = 0 { // If there is no booster go straight to catch mode. Normally activated when the tower is loaded while booster is on it's way back.
    set runmode to 3.
}

set internalTimer to 0.
set startTime to time:seconds.
set liftoffTime to 0.

set chopsticks to ship:partsdubbed("SLE.SS.OLIT.MZ").
set boosterAngle to 0.

set boosterName to "".
set boosterGeoPos to latlng(0, 0).
set boosterAlt to 0.
set boosterThrust to 0. // If thrust is 0, landing rails will lower
set boosterOriginPoint to latlng(0, 0). // Used for calculating booster distance away from the pad

manageIncomingMessages().

// TODO - Control rates of movements 0.2 vertical, 10 l/r & close for catch 0.1 or so for movements after, 0.1 pushers, Make sure QD arm is retracted

until runmode = 0 {
    set internalTimer to time:seconds - startTime.
    printData().
    manageIncomingMessages().
    if runmode = 1 { // Countdown / Initial Liftoff - Open the sticks at the top of the tower and raise landing rails for liftoff
        if ship:partsdubbed("SEP.25.BOOSTER.CORE"):length = 0 and ship:partsdubbed("SEP.23.BOOSTER.INTEGRATED"):length = 0 { // Works with both release and beta SEP boosters
            if liftoffTime = 0 {
                set liftoffTime to internalTimer.
            }
            if internalTimer >= liftoffTime + 15 {
                set runmode to 2.
            }
        }
        chopsticksOpenClose(True, 113.5, 0).
        chopsticksVertical(2).
        chopsticksLandingRails(True).
    } 
    if runmode = 2 { // After liftoff / Pre-Catch - Close sticks after liftoff to where they will be for catch
        chopsticksOpenClose(True, 30, 8.6).
        chopsticksVertical(2).
        chopsticksLandingRails(True).
        if internalTimer >= liftoffTime + 300 { // Tower will probably be unloaded by this point. This is here so if it isn't unloaded somehow the script can still move to catch mode.
            set runmode to 3.
        }
    }
    if runmode = 3 { // Catch
        local distanceToBooster is (boosterOriginPoint:position - boosterGeoPos:position):mag. // Output in meters

        if distanceToBooster <= 15 and boosterAlt < 160 {
            chopsticksOpenClose(False, 0, boosterAngle).
            chopsticksLandingRails(True).
            if boosterThrust = 0 and boosterAlt < 180 {
                chopsticksLandingRails(False).
                set runmode to 0.
            }
        } else {
            set boosterAngle to (boosterGeoPos:heading - 90) + 8.6.
            chopsticksOpenClose(True, 30, boosterAngle).
            chopsticksVertical(2).
            chopsticksLandingRails(True).
        }
    }
    wait 0.
}

function chopsticksOpenClose {
    parameter openSticks, openAngle, angle.
    set chopsticksAngleModule to chopsticks[0]:getModuleByIndex(8). // 6 on non-experimental sticks
    if openSticks {
        if chopsticksAngleModule:hasEvent("open arms") {
            chopsticksAngleModule:doEvent("open arms").
        }
        chopsticksAngleModule:setField("arms open angle", openAngle).
        chopsticksAngleModule:setField("target angle", angle).
    } else if chopsticksAngleModule:hasEvent("close arms") {
        chopsticksAngleModule:doEvent("close arms").
    }
}

function chopsticksVertical {
    parameter height.
    set chopsticksVerticalModule to chopsticks[0]:getModuleByIndex(3). // 1 on non-experimental sticks
    chopsticksVerticalModule:setField("target extension", height).
}

function chopsticksLandingRails { // Comment this function out if using non-experimental version sticks
    parameter raised.
    set chopsticksRails to chopsticks[0]:getModuleByIndex(12). 
    if raised and chopsticksRails:hasEvent("raise landing rails") { 
        chopsticksRails:doEvent("raise landing rails").
    } else if not raised and chopsticksRails:hasEvent("lower landing rails") {
        chopsticksRails:doEvent("lower landing rails").
    }
}

function manageIncomingMessages {
    local boosterMsgs is ship:messages.
    if boosterMsgs:length > 0 {
        local boosterNewMsg is boosterMsgs:pop.
        set boosterName to boosterNewMsg:content["NameOfShip"] + " Ship".
        set boosterGeoPos to boosterNewMsg:content["GeoPos"].
        set boosterAlt to boosterNewMsg:content["Alt"].
        set boosterThrust to boosterNewMsg:content["Thrust"].
        set boosterOriginPoint to boosterNewMsg:content["OriginPoint"].
        boosterMsgs:clear.
    }
}

function printData {
    clearscreen.
    print("----- Chopstick Data -----") at(0, 0).
    print("Target Angle: " + round(chopsticks[0]:getModuleByIndex(8):getField("target angle"), 2)) at(0, 1).
    print("Target Height: " + round(chopsticks[0]:getModuleByIndex(3):getField("target extension"), 2)) at(0, 2).
    print("Chopsticks Open: " + chopsticks[0]:getModuleByIndex(8):hasEvent("close arms")) at(0, 3).

    print("Current Angle: " + round(chopsticks[0]:getModuleByIndex(8):getField("target angle"), 2)) at(0, 5).
    print("Current Height: " + round(chopsticks[0]:getModuleByIndex(3):getField("target extension"), 2)) at(0, 6).

    print("----- Booster Data -----") at(0, 8).
    print("Booster: " + boosterName) at(0, 9).
    print("Booster GeoPos: " + boosterGeoPos) at(0, 10).
    print("Booster Altitude: " + round(boosterAlt, 2)) at(0, 11).
    print("Message Queue Length: " + ship:messages:length) at(0, 12).
}