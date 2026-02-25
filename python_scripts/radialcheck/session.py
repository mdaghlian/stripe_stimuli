#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Feb 25 14:05:10 2019

@author: marcoaqil
"""

import numpy as np
import os
from psychopy import visual
from psychopy.visual import filters
from psychopy import tools
from exptools2.core import Session, PylinkEyetrackerSession
from exptools2.core.session import Session
from trial import RADCHTrial
from stim import RadialCheckerboard, FixationBullsEye

opj = os.path.join



class RADCHSession(PylinkEyetrackerSession):

    
    def __init__(self, output_str, output_dir, settings_file, eyetracker_on=False):
        
        
        super().__init__(output_str=output_str, output_dir=output_dir, settings_file=settings_file, eyetracker_on=eyetracker_on)
        #if we are scanning, here I set the mri_trigger manually to the 't'. together with the change in trial.py, this ensures syncing
        if self.settings['mri']['topup_scan']==True:
            self.topup_scan_duration=self.settings['mri']['topup_duration']
        if self.settings['stim_settings']['scanner_sync']==True:
            self.trial_length = self.settings['mri']['TR']
            self.mri_trigger=self.settings['mri']['trigger']
        else:
            self.trial_length = self.settings['stim_settings']['trial_length']
        if self.settings['stim_settings']['screenshot']==True:
            self.screen_dir=output_dir+'/'+output_str+'_screenshots'
            if not os.path.exists(self.screen_dir):
                os.mkdir(self.screen_dir)

        #create all stimuli and trials at the beginning of the experiment, to save time and resources        
        self.create_stimuli()
        self.create_trials()
            

    def create_stimuli(self):
        

        
        #generate PRF stimulus
        self.radch_stim = RadialCheckerboard(
            session=self, 
            n_wedges=self.settings['stim_settings']['n_wedges'],
            n_rings=self.settings['stim_settings']['n_rings'],
            radius_deg=self.settings['stim_settings']['radius_deg'],
            tex_nr_pix=self.settings['stim_settings']['tex_nr_pix'],
            flicker_frequency=self.settings['stim_settings']['flicker_frequency'],
            animation_type='reversing', 
            n_phases=2,
            )    
        

        #currently unused
        # self.instruction_string = """Please fixate in the center of the screen. Your task is to respond whenever the dot changes color."""
        

        #generate raised cosine alpha mask
        mask = filters.makeMask(matrixSize=self.win.size[0], 
                                shape='raisedCosine', 
                                radius=np.array([self.win.size[1]/self.win.size[0], 1.0]),
                                center=(0.0, 0.0), 
                                range=[-1, 1], 
                                fringeWidth=0.02
                                )

        #adjust mask size in case the stimulus runs on a mac 
        if self.settings['operating system'] == 'mac':
            mask_size = [self.win.size[0]/2,self.win.size[1]/2]
        else: 
            mask_size = [self.win.size[0],self.win.size[1]]
            
        self.mask_stim = visual.GratingStim(self.win, 
                                        mask=-mask, 
                                        tex=None, 
                                        units='pix',
                                        
                                        size=mask_size, 
                                        pos = np.array((0.0,0.0)), 
                                        color = [0,0,0]) 
        



        #as current basic task, generate fixation circles of different colors, with black border
        fixation_radius_pixels=tools.monitorunittools.deg2pix(self.settings['stim_settings']['size_fixation_dot_in_degrees'], self.monitor)/2            
        if self.settings['stim_settings']['fixation_method'] == 'dot':        
            #two colors of the fixation circle for the task
            self.fixation_disk_0 = visual.Circle(self.win, 
                units='pix', radius=fixation_radius_pixels, 
                fillColor=[1,-1,-1], lineColor=[1,-1,-1])
            
            self.fixation_disk_1 = visual.Circle(self.win, 
                units='pix', radius=fixation_radius_pixels, 
                fillColor=[-1,1,-1], lineColor=[-1,1,-1])
        elif self.settings['stim_settings']['fixation_method'] == 'cross':
            # line_width=tools.monitorunittools.deg2pix(
            #     self.settings['stim_settings']['fix_cross_parameters']['line_width'],
            #     self.monitor)  
            # print(line_width)          
            line_width=self.settings['stim_settings']['fix_cross_parameters']['line_width']
            dot_radius=self.settings['stim_settings']['fix_cross_parameters']['dot_radius']
            line_radius=500 # hackyy to make it all the way...
            # Green 
            self.fixation_disk_0 =  FixationBullsEye(
                win=self.win,
                # fix_col=[1,-1,-1],
                fix_col=[-1,-1,-1],
                line_width=line_width,
                dot_radius=dot_radius,
                line_radius=line_radius,
            )
            # Red
            self.fixation_disk_1 =  FixationBullsEye(
                win=self.win,
                # fix_col=[-1,1,-1],
                fix_col=[1,1,1],
                line_width=line_width,
                dot_radius=dot_radius,
                line_radius=line_radius,
            )

    def create_trials(self):
        """creates trials by setting up prf stimulus sequence"""
        self.trial_list=[]
        
        #simple tools to check subject responses online
        self.correct_responses = 0
        self.total_responses = 0
        self.dot_count = 0
        

        #create as many trials as TRs. 5 extra TRs at beginning + bar passes + blanks
        self.trial_number = self.settings['stim_settings']['start_blanks'] + \
            (self.settings['stim_settings']['on_time'] * self.settings['stim_settings']['on_off_cycles']) + \
            (self.settings['stim_settings']['off_time'] * self.settings['stim_settings']['on_off_cycles']) + \
            self.settings['stim_settings']['end_blanks']
  
        print("Expected number of TRs: %d"%self.trial_number)
        on_off_cycle = [*[1]*self.settings['stim_settings']['on_time'], *[0]*self.settings['stim_settings']['off_time']]

        self.trial_on_off = []
        self.trial_on_off.extend(
            [0]*self.settings['stim_settings']['start_blanks']
        )
        for i in range(self.settings['stim_settings']['on_off_cycles']):
            self.trial_on_off.extend(on_off_cycle)
        self.trial_on_off.extend(
            [0]*self.settings['stim_settings']['end_blanks']
        )
        print(f"Number of trials in on off array = {len(self.trial_on_off)}")
        print(self.trial_on_off)
        #trial list
        for i in range(self.trial_number):
                
            self.trial_list.append(RADCHTrial(session=self,
                                            trial_nr=i,
                                            on_off=self.trial_on_off[i],
                           ))


        #times for dot color change. continue the task into the topup
        self.total_time = self.trial_number*self.trial_length 
        
        if self.settings['mri']['topup_scan']==True:
            self.total_time += self.topup_scan_duration
        
        
        #DOT COLOR CHANGE TIMES    
        self.dot_switch_color_times = np.arange(3, self.total_time, float(self.settings['task_settings']['color_switch_interval']))
        self.dot_switch_color_times += (2*np.random.rand(len(self.dot_switch_color_times))-1)
        
        
        #needed to keep track of which dot to print
        self.current_dot_time=0
        self.next_dot_time=1

        #only for testing purposes
        np.save(opj(self.output_dir, self.output_str+'_DotSwitchColorTimes.npy'), self.dot_switch_color_times)
        print(self.win.size)

    def draw_stimulus(self):
        present_time = self.clock.getTime()
        
        #present_trial_time = self.clock.getTime() - self.current_trial_start_time
        t_time = present_time #/ (self.bar_step_length)
        
        if self.current_trial.on_off != 0:
            self.radch_stim.draw(time=t_time)
            
        #hacky way to draw the correct dot color. could be improved
        if self.next_dot_time<len(self.dot_switch_color_times):
            if present_time<self.dot_switch_color_times[self.current_dot_time]:                
                self.fixation_disk_1.draw()
            else:
                if present_time<self.dot_switch_color_times[self.next_dot_time]:
                    self.fixation_disk_0.draw()
                else:
                    self.current_dot_time+=2
                    self.next_dot_time+=2
                    



    def run(self):
        """run the session"""
        # cycle through trials
        if self.eyetracker_on:
            self.calibrate_eyetracker()

        self.display_text('Waiting for scanner', keys=self.settings['mri'].get('sync', 't'))

        self.start_experiment()
        
        if self.eyetracker_on:
            self.start_recording_eyetracker()            

        for trial_idx in range(len(self.trial_list)):
            self.current_trial = self.trial_list[trial_idx]
            self.current_trial_start_time = self.clock.getTime()
            self.current_trial.run()
        
        print(f"Expected number of responses: {len(self.dot_switch_color_times)}")
        print(f"Total subject responses: {self.total_responses}")
        print(f"Correct responses (within {self.settings['task_settings']['response_interval']}s of dot color change): {self.correct_responses}")
        np.save(opj(self.output_dir, self.output_str+'_simple_response_data.npy'), {"Expected number of responses":len(self.dot_switch_color_times),
        														                      "Total subject responses":self.total_responses,
        														                      f"Correct responses (within {self.settings['task_settings']['response_interval']}s of dot color change)":self.correct_responses})
        
        #print('Percentage of correctly answered trials: %.2f%%'%(100*self.correct_responses/len(self.dot_switch_color_times)))
        
        
        if self.settings['stim_settings']['screenshot']==True:
            self.win.saveMovieFrames(opj(self.screen_dir, self.output_str+'_screenshot.png'))
            
        self.close()

        

