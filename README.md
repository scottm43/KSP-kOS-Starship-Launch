# KSP-kOS-Starship-Launch

This is a series of scripts I wrote to recreate SpaceX's Superheavy tower catch. In the current state, these scripts are focussed only on catching the booster and just getting through hotstaging with the ship.

The script is very rough and doesn't work every time but for not being an experienced programmer I don't think it's too bad.

Script Requirements & Recommendations:
- The booster needs to use 33 induvidual engines instead of the cluster
- The center 13 engines on the booster need the name tag "BoosterRC" - An easy way to do this is to place one engine, name that and then place again with symmetry and make sure to place the 3 middle engines before the ring of 10.
- The 3 sea level engines on ship needs the name tag "ShipRC"
- The booster needs a GRAVMAX Gravioli Detector
- I recommend putting AutoChopticks.ks and Starship.ks in the "boot" folder and setting them to auto run on the tower base and ship

Mod Dependencies:
- Starship Expansion Project v3.0.0-b5
- Starship Launch Expansion Experimental
- Kerbal Operating System
- Realism Overhaul & RSS or Sol
- Trajectories
- Atmospheric Autopilot
