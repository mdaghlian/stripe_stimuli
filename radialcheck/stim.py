#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Radial Checkerboard Stimulus
Adapted from PRFStim for radial/polar checkerboard patterns

Features:
- Control spatial frequency (number of wedges and rings)
- Control phase (rotation and radial offset)
- Flickering animation capability
"""
import numpy as np
from psychopy import visual
from psychopy import tools
import math


class RadialCheckerboard(object):
    def __init__(self, session,
                 n_wedges=16,
                 n_rings=8,
                 radius_deg=10,
                 tex_nr_pix=1024,
                 flicker_frequency=6,
                 animation_type='moving',
                 n_phases=8,
                 **kwargs):
        """
        Initialize radial checkerboard stimulus
        
        Parameters:
        -----------
        session : object
            PsychoPy session object with .win and .monitor attributes
        n_wedges : int
            Number of angular wedges (angular spatial frequency)
        n_rings : int
            Number of concentric rings (radial spatial frequency)
        radius_deg : float
            Radius of the checkerboard in degrees of visual angle
        tex_nr_pix : int
            Texture resolution in pixels (square texture)
        flicker_frequency : float
            Frequency of checkerboard flicker in Hz
        animation_type : str
            Type of animation: 'moving' (rotating), 'reversing' (phase reversal),
            'radial_moving' (expanding/contracting), or 'static'
        n_phases : int
            Number of phases for animation (2 for simple reversal, 
            4+ for smoother transitions, 8 is default for moving)
        """
        self.session = session
        self.n_wedges = n_wedges
        self.n_rings = n_rings
        self.radius_deg = radius_deg
        self.animation_type = animation_type
        self.n_phases = n_phases
        
        # Ensure tex_nr_pix is a power of 2 (required by PsychoPy)
        self.tex_nr_pix = int(2 ** np.round(np.log2(tex_nr_pix)))
        if self.tex_nr_pix != tex_nr_pix:
            print(f"Warning: tex_nr_pix adjusted from {tex_nr_pix} to {self.tex_nr_pix} (power of 2)")
        
        self.flicker_frequency = flicker_frequency
        
        # Calculate radius in pixels
        self.radius_pix = tools.monitorunittools.deg2pix(
            radius_deg, self.session.monitor
        ) * self.tex_nr_pix / self.session.win.size[1]
        
        # Create the base checkerboard textures
        self._create_textures()
        
        # Create PsychoPy stimulus objects with different phases
        self._create_stimuli()
    
    def _create_textures(self):
        """Create radial checkerboard textures with different phases"""
        # Create coordinate grids
        x = np.linspace(-self.tex_nr_pix/2, self.tex_nr_pix/2, self.tex_nr_pix)
        y = np.linspace(-self.tex_nr_pix/2, self.tex_nr_pix/2, self.tex_nr_pix)
        X, Y = np.meshgrid(x, y)
        
        # Convert to polar coordinates
        R = np.sqrt(X**2 + Y**2)
        Theta = np.arctan2(Y, X)
        
        # Create mask for circular aperture
        mask = R <= self.radius_pix
        
        # Create base checkerboard pattern
        # Angular component: n_wedges wedges around the circle
        angular_pattern = np.sin(self.n_wedges * Theta)
        
        # Radial component: n_rings concentric rings
        # Scale radius to create the desired number of rings
        radial_pattern = np.sin(self.n_rings * np.pi * R / self.radius_pix)
        
        # Combine to create checkerboard
        self.base_texture = np.sign(angular_pattern * radial_pattern)
        self.base_texture[~mask] = 0  # Apply circular mask
        
        # Create phase-shifted versions based on animation type
        self.textures = []
        
        if self.animation_type == 'reversing':
            # Phase reversal: alternate between normal and inverted
            # n_phases determines smoothness of transition
            for i in range(self.n_phases):
                # Smooth transition using cosine
                phase_weight = np.cos(i * np.pi / (self.n_phases - 1)) if self.n_phases > 1 else 1
                
                if self.n_phases == 2:
                    # Simple binary reversal
                    texture = self.base_texture if i == 0 else -self.base_texture
                else:
                    # Smooth reversal (fades through gray)
                    texture = self.base_texture * phase_weight
                
                texture[~mask] = 0
                self.textures.append(texture)
        
        elif self.animation_type == 'moving':
            # Rotating animation: shift angular phase
            for i in range(self.n_phases):
                phase_angular = i * 2 * np.pi / self.n_phases
                
                angular_pattern = np.sin(self.n_wedges * Theta + phase_angular)
                radial_pattern = np.sin(self.n_rings * np.pi * R / self.radius_pix)
                
                texture = np.sign(angular_pattern * radial_pattern)
                texture[~mask] = 0
                self.textures.append(texture)
        
        elif self.animation_type == 'radial_moving':
            # Expanding/contracting: shift radial phase
            for i in range(self.n_phases):
                phase_radial = i * 2 * np.pi / self.n_phases
                
                angular_pattern = np.sin(self.n_wedges * Theta)
                radial_pattern = np.sin(self.n_rings * np.pi * R / self.radius_pix + phase_radial)
                
                texture = np.sign(angular_pattern * radial_pattern)
                texture[~mask] = 0
                self.textures.append(texture)
        
        elif self.animation_type == 'combined_moving':
            # Both angular and radial movement
            for i in range(self.n_phases):
                phase_angular = i * 2 * np.pi / self.n_phases
                phase_radial = i * 2 * np.pi / self.n_phases
                
                angular_pattern = np.sin(self.n_wedges * Theta + phase_angular)
                radial_pattern = np.sin(self.n_rings * np.pi * R / self.radius_pix + phase_radial)
                
                texture = np.sign(angular_pattern * radial_pattern)
                texture[~mask] = 0
                self.textures.append(texture)
        
        else:  # 'static' or unknown
            # Just create the base texture
            self.textures.append(self.base_texture)
    
    def _create_stimuli(self):
        """Create PsychoPy GratingStim objects for each texture phase"""
        self.stimuli = []
        
        for texture in self.textures:
            stim = visual.GratingStim(
                self.session.win,
                tex=texture,
                units='pix',
                size=[self.session.win.size[1], self.session.win.size[1]],
                mask=None
            )
            self.stimuli.append(stim)
    
    def draw(self, time, position=(0, 0), contrast=1.0):
        """
        Draw the radial checkerboard at the current time
        
        Parameters:
        -----------
        time : float
            Current time in seconds (used for animation)
        position : tuple
            (x, y) position in pixels
        contrast : float
            Contrast multiplier (0 to 1)
        """
        # Calculate which phase to show based on time
        phase_index = int((time * self.flicker_frequency * self.n_phases) % self.n_phases)
        
        # Set position and contrast
        self.stimuli[phase_index].setPos(position)
        self.stimuli[phase_index].setContrast(contrast)
        
        # Draw the stimulus
        self.stimuli[phase_index].draw()
    
    def draw_static(self, angular_phase=0, radial_phase=0, position=(0, 0), contrast=1.0):
        """
        Draw a static checkerboard with custom phase
        
        Parameters:
        -----------
        angular_phase : float
            Angular phase offset in radians
        radial_phase : float
            Radial phase offset in radians
        position : tuple
            (x, y) position in pixels
        contrast : float
            Contrast multiplier (0 to 1)
        """
        # Create coordinate grids
        x = np.linspace(-self.tex_nr_pix/2, self.tex_nr_pix/2, self.tex_nr_pix)
        y = np.linspace(-self.tex_nr_pix/2, self.tex_nr_pix/2, self.tex_nr_pix)
        X, Y = np.meshgrid(x, y)
        
        # Convert to polar coordinates
        R = np.sqrt(X**2 + Y**2)
        Theta = np.arctan2(Y, X)
        
        # Create mask
        mask = R <= self.radius_pix
        
        # Create checkerboard with specified phases
        angular_pattern = np.sin(self.n_wedges * Theta + angular_phase)
        radial_pattern = np.sin(self.n_rings * np.pi * R / self.radius_pix + radial_phase)
        
        texture = np.sign(angular_pattern * radial_pattern)
        texture[~mask] = 0
        
        # Create temporary stimulus
        stim = visual.GratingStim(
            self.session.win,
            tex=texture,
            units='pix',
            size=[self.session.win.size[1], self.session.win.size[1]],
            mask=None
        )
        
        stim.setPos(position)
        stim.setContrast(contrast)
        stim.draw()
    
    def update_spatial_frequency(self, n_wedges=None, n_rings=None):
        """
        Update spatial frequency and regenerate textures
        
        Parameters:
        -----------
        n_wedges : int, optional
            New number of wedges
        n_rings : int, optional
            New number of rings
        """
        if n_wedges is not None:
            self.n_wedges = n_wedges
        if n_rings is not None:
            self.n_rings = n_rings
        
        # Regenerate textures and stimuli
        self._create_textures()
        self._create_stimuli()
    
    def set_animation_type(self, animation_type, n_phases=None):
        """
        Change animation type and regenerate textures
        
        Parameters:
        -----------
        animation_type : str
            'reversing', 'moving', 'radial_moving', 'combined_moving', or 'static'
        n_phases : int, optional
            Number of phases (if None, keeps current value)
        """
        self.animation_type = animation_type
        if n_phases is not None:
            self.n_phases = n_phases
        
        # Regenerate textures and stimuli with new animation type
        self._create_textures()
        self._create_stimuli()


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