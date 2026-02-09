#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Drifting Gratings Stimulus
Adapted from PRFStim code

@author: adapted from marcoaqil's PRF code
"""
import numpy as np
from psychopy import visual
from psychopy import tools
import math


class DriftingGratings(object):
    def __init__(self, session,
                 orientations,  # list of orientations in degrees (0 = vertical grating)
                 spatial_frequency=2.0,  # cycles per degree
                 speed_deg_per_sec=4.0,  # degrees per second
                 radius_deg=10,  # radius of the grating patch in degrees
                 contrast=1.0,  # contrast of the grating (0-1)
                 **kwargs):
        """
        Create a drifting grating stimulus with pre-created textures for multiple orientations.
        
        Parameters:
        -----------
        session : object
            Session object containing win (window) and monitor attributes
        orientations : list of float
            List of orientations in degrees (e.g., [0, 45, 90, 135])
            0 = vertical stripes, 90 = horizontal stripes
        spatial_frequency : float
            Spatial frequency in cycles per degree
        speed_deg_per_sec : float
            Drift speed in degrees per second
        radius_deg : float
            Radius of the grating patch in degrees of visual angle
        contrast : float
            Contrast of the grating (0 to 1)
            
        Notes:
        ------
        The relationship between speed and temporal frequency is:
        temporal_frequency (Hz) = speed (deg/s) * spatial_frequency (cycles/deg)
        
        All grating stimuli are pre-created at initialization to avoid speed issues
        during runtime. Call draw(time, orientation) to display a specific orientation.
        """
        self.session = session
        self.spatial_frequency = spatial_frequency
        self.speed_deg_per_sec = speed_deg_per_sec
        self.radius_deg = radius_deg
        self.orientations = orientations
        self.contrast = contrast
        
        # Calculate temporal frequency from speed and spatial frequency
        # temporal_frequency = speed * spatial_frequency
        self.temporal_frequency = self.speed_deg_per_sec * self.spatial_frequency
        
        # Pre-create all grating stimuli for each orientation
        self.gratings = {}
        for ori in self.orientations:
            self.gratings[ori] = visual.GratingStim(
                win=self.session.win,
                tex='sqr',  # sinusoidal grating
                mask='circle',  # circular aperture (can also be 'gauss', None, etc.)
                units='deg',
                size=self.radius_deg * 2,  # size is diameter, not radius
                sf=self.spatial_frequency,  # spatial frequency
                ori=ori,
                contrast=self.contrast,
                phase=0  # will be updated during drawing
            )
    
    def draw(self, time, orientation):
        """
        Draw the drifting grating at the current time with specified orientation.
        
        Parameters:
        -----------
        time : float
            Current time in seconds. The phase will be calculated based on this.
        orientation : float
            Orientation to display (must be one of the orientations specified at init)
        """
        if orientation not in self.gratings:
            raise ValueError(f"Orientation {orientation} not found. Available orientations: {list(self.gratings.keys())}")
        
        # Calculate phase based on time and temporal frequency
        # Phase advances by temporal_frequency cycles per second
        phase = self.temporal_frequency * time
        
        # Set the phase and draw the selected orientation
        self.gratings[orientation].phase = phase
        self.gratings[orientation].draw()
    
    def set_spatial_frequency(self, sf):
        """
        Change the spatial frequency of all gratings.
        Also updates temporal frequency to maintain the same speed.
        """
        self.spatial_frequency = sf
        for grating in self.gratings.values():
            grating.sf = sf
        # Recalculate temporal frequency to maintain speed
        self.temporal_frequency = self.speed_deg_per_sec * self.spatial_frequency
    
    def set_speed(self, speed_deg_per_sec):
        """
        Change the drift speed in degrees per second.
        
        Parameters:
        -----------
        speed_deg_per_sec : float
            New drift speed in degrees per second
        """
        self.speed_deg_per_sec = speed_deg_per_sec
        self.temporal_frequency = self.speed_deg_per_sec * self.spatial_frequency
    
    def set_temporal_frequency(self, tf):
        """
        Change the temporal frequency (drift speed) directly in Hz.
        Also updates the speed_deg_per_sec accordingly.
        
        Parameters:
        -----------
        tf : float
            Temporal frequency in Hz
        """
        self.temporal_frequency = tf
        self.speed_deg_per_sec = self.temporal_frequency / self.spatial_frequency
    
    def set_contrast(self, contrast):
        """Change the contrast of all gratings."""
        self.contrast = contrast
        for grating in self.gratings.values():
            grating.contrast = contrast
    
    def set_position(self, pos):
        """
        Set the position of all gratings.
        
        Parameters:
        -----------
        pos : tuple
            (x, y) position in degrees
        """
        for grating in self.gratings.values():
            grating.pos = pos
    
    def set_radius(self, radius_deg):
        """
        Change the radius of all gratings.
        
        Parameters:
        -----------
        radius_deg : float
            New radius in degrees of visual angle
        """
        self.radius_deg = radius_deg
        for grating in self.gratings.values():
            grating.size = self.radius_deg * 2  # size is diameter
    
    def get_temporal_frequency(self):
        """Get the current temporal frequency in Hz."""
        return self.temporal_frequency
    
    def get_speed(self):
        """Get the current speed in degrees per second."""
        return self.speed_deg_per_sec
    
    def get_available_orientations(self):
        """Get list of available orientations."""
        return list(self.gratings.keys())


class FixationBullsEye(object):
    def __init__(self, win, fix_col, line_width, dot_radius, line_radius):
        self.fix_col = fix_col
        self.line_width = line_width
        self.dot_radius = dot_radius
        self.line_radius = line_radius

        # Calculate sin and cos of 45 degrees (or pi/4 radians) for line endpoints
        # Using math.radians to convert degrees to radians for math functions
        sin_45 = math.sin(math.radians(45))
        cos_45 = math.cos(math.radians(45))

        # Line 1: Goes from bottom-left to top-right (45 degrees from horizontal)
        line1_start = (-self.line_radius * cos_45, -self.line_radius * sin_45)
        line1_end = (self.line_radius * cos_45, self.line_radius * sin_45)

        # Line 2: Goes from top-left to bottom-right (135 degrees from horizontal, or -45 degrees)
        line2_start = (-self.line_radius * cos_45, self.line_radius * sin_45)
        line2_end = (self.line_radius * cos_45, -self.line_radius * sin_45)

        # --- Create Stimuli ---
        # Create the first line stimulus
        self.cross_line1 = visual.Line(
            win=win,
            start=line1_start,
            end=line1_end,
            lineWidth=self.line_width,
            lineColor=self.fix_col,
            units='deg' 
        )

        # Create the second line stimulus
        self.cross_line2 = visual.Line(
            win=win,
            start=line2_start,
            end=line2_end,
            lineWidth=self.line_width,
            lineColor=self.fix_col,
            units='deg' 
        )

        # # Create the central dot stimulus
        # self.center_dot = visual.Circle(
        #     win=win,
        #     radius=self.dot_radius,
        #     fillColor=self.fix_col,
        #     lineColor=None, # No border for the dot
        #     units='deg'
        # )
    def draw(self):
        # --- Drawing and Displaying ---
        # Draw all stimuli to the back buffer
        self.cross_line1.draw()
        self.cross_line2.draw()
        # self.center_dot.draw()