# SolarCharger
Smart charge your ev-car to a percentage when the sun shines enough and the house it not using too much.

## Features
- low system requriements - runs on a router
- self contained, no need to install additional software/modules
- website for overview, changing settings and manual starting a charge
- charge your car only to a specific percentage (not full)
- when over 70% limit charge car until 90% to not waste solar energy
- continous adoption to current pv generation

## Overview
The script reads the live values from the pv-system, current house consumption, battery state of the car and charges the car according to the settings done on the website it generates. The generated website looks like this:

<img src="images/Website.png" style="max-width: 90%; display: block; margin-left: auto; margin-right: auto;" /> 

A typical day (with charging in the afternoon) looks like:

<img src="images/SMA.png" style="max-width: 90%; display: block; margin-left: auto; margin-right: auto;" /> 

## Supported Systems

The system uses classes for accessing the various hardware devices. Currently the following classes are included:

- generic Modbus over Ethernet access class
- SMAReader a class for specifying which modbus values represent solar inverter and household state
- PhoenixCharger a modbus extension to specify which values are which on the phoenix charger
- BMWConnector reads in json file from website to know if the car is at home and percentage of the battery if not used it will charge to 100%

The system generates a website (default is http://localhost:5145 ) which lets you set the default settings. 

I do have a BMW and if that's hat home it only gets charged when it's below a set state e.g. 80%. I do have a 70% feed in rule so I charge the car regardless of it's charging state if the solar system would be cut down to 70% otherwise. It will charge then with 6A and only until 90%.

## Configuration

Change the config.ini file to use the ipaddresses/names for your setup. Start the script for testing with perl startcharger.perl --help


