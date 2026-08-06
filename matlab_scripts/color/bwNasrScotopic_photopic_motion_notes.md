# Converting `bwNasrScotopic.m` into a photopic motion-sensitive (thick-type / MT) stripe localizer

## Where the current script's parameters come from

`bwNasrScotopic.m` implements the **scotopic control stimulus** from:

> Tootell RBH & Nasr S (2021). *Scotopic Vision Is Selectively Processed in Thick-Type Columns in Human Extrastriate Cortex.* Cerebral Cortex, 31(2), 1163–1181. https://academic.oup.com/cercor/article/31/2/1163/5929822 (PDF: https://mesovision.martinos.org/wp-content/uploads/2020/10/Tootell-Nasr-2020-Scotopic-Vision-is-Selectively-Processed-in-Thick-Type-Columns-in-Human-Extrastriate-Cortex.pdf)

Direct quotes from the Methods:

> "Stimuli were achromatic square wave gratings (0.2 cycles/degree) moving continuously at 4°/s... Here, motion direction was reversed every 6 s to reduce possible effect(s) of motion adaptation." (dark-adapted, scotopic light level)

> "The spatial frequency of the gratings (0.2 c/deg) was chosen mainly because both thick- and thin-type columns produced essentially equally strong responses to this spatial frequency... (Tootell and Nasr 2017)."

That last line is the key point: **0.2 cyc/deg was deliberately chosen to *not* favor the motion-sensitive (thick-type) columns over the color-sensitive (thin-type) columns.** It's an unbiased probe, not a motion localizer. So the current script, as written, is not well suited to isolating motion-sensitive stripes — even under photopic light, it would drive thin- and thick-type columns about equally.

## What the same paper says about localizing motion-sensitive (thick-type / MT) columns

The companion "Localization of Thick-Type Columns" method in the same paper (photopic condition, run in the same subjects):

> "Multiple control and localization stimuli were presented at photopic luminance level (mean = 52 cd/m²)."

> "Thick-type columns were localized by contrasting the activity produced by **moving (vs. stationary) gratings**. This motion-based localization in human thick-type stripes is consistent with single-unit and imaging-based studies in nonhuman primates... MT was defined as a site in the medial temporal sulcus which responds strongly to the moving versus stationary stimulus contrast."

So the defining feature of a motion-sensitive-stripe localizer isn't a special spatial frequency — it's the **contrast**: identical grating, alternated between a *moving* epoch and a *static* (frozen) epoch, with the GLM regressor of interest being moving > stationary (not moving > blank, which would be confounded by stimulus onset/luminance).

The paper does not give an explicit block duration for this specific localizer (unlike the thin-column/color localizer, which is fully specified — see below), so that part is a recommendation, not a sourced number.

## Supporting source: why low spatial frequency / high temporal frequency biases toward the motion (M) pathway

> Tootell RBH & Nasr S (2017). *Columnar Segregation of Magnocellular and Parvocellular Streams in Human Extrastriate Cortex.* J Neurosci, 37(33), 8014–8032. https://www.jneurosci.org/content/37/33/8014 (PDF: https://mesovision.martinos.org/wp-content/uploads/2020/09/Tootell-Nasr-2017-Columnar-segregation-of-magnocellular-and-parvocellular-streams-in-human-extrastriate-cortex.pdf)

This is the paper that established *why* 0.2 cyc/deg is a "neutral" spatial frequency, and it swept spatial frequency explicitly:

> "Subjects were presented with gratings of differing achromatic contrast (1.43%, 5.25%, 15.95%, 50.14%, and 99.62%) and spatial frequency (**0.1, 0.27, 0.73, 2.08, and 5.79 cycles/degree**) across different blocks, in a 5×5 design."

And, citing the classic M/P physiology literature (Derrington & Lennie 1984; Shapley et al. 1981):

> "...more sensitive to high temporal frequencies... and lower spatial frequencies... [magnocellular / M-stream, which feeds thick-type columns and MT]."

So if you want a stimulus that is *biased toward* (not just compatible with) the motion pathway, the literature points to lower spatial frequency and/or higher temporal frequency (faster drift, or a higher reversal rate) than the 0.2 cyc/deg @ 4°/s scotopic compromise — e.g., something nearer the 0.1 cyc/deg end of the sweep above, rather than 0.73–5.79 cyc/deg (which biases toward parvocellular/thin columns).

Also worth noting: thick-type (motion/disparity) columns in this same lab's earlier work were more commonly localized with **binocular disparity** (random-dot stereograms), not motion — see Nasr S, Polimeni JR, Tootell RBH (2016), *Interdigitated Color- and Disparity-Selective Columns within Human Visual Cortical Areas V2 and V3*, J Neurosci 36(6):1841–1857 (https://pubmed.ncbi.nlm.nih.gov/26865609/). That's the paradigm already implemented in `disparityProject.m` in this repo. The moving-vs-stationary grating approach above is the one to use specifically when you want an **MT-localizing, motion-selective** contrast (the 2016/2017 disparity scans didn't even cover MT in their field of view).

## Concrete changes needed in the script

1. **Light level (not really a code change).** Drop the scotopic setup: no neutral-density filtering, no ≥15 min dark adaptation, no room-lights-off. Present at a normal photopic mean luminance (paper used 52 cd/m²). `bwNasrScotopic.m` itself doesn't model scotopic attenuation in code — that was done physically with Wratten ND filters in front of the projector — so this is a hardware/room-setup change, not a MATLAB change.

2. **Add a "stationary" condition (the core change).** Currently every stim block is continuously drifting, and the only other condition is blank/rest. Add a second stimulus condition — the identical grating, same orientation/contrast/spatial frequency, but with `direction = 0` (no phase update) for the whole block. Alternate `moving` and `stationary` blocks (instead of `moving` vs `blank` only), and carry both as separate regressors in the `Cond.mat` output, e.g. `names = {'rest','moving','stationary'}`. The contrast of interest downstream is `moving − stationary`.

3. **Consider biasing spatial/temporal frequency toward M/motion tuning**, if you want a stronger (not just "MT-compatible") motion signal, rather than reusing the "equally-effective-for-both" 0.2 cyc/deg value:
   - Lower spatial frequency (the 2017 sweep tested 0.1, 0.27, 0.73, 2.08, 5.79 cyc/deg — 0.1 or 0.27 cyc/deg would trend toward M-biased).
   - Same or higher speed/temporal frequency is fine or preferable (4°/s at 0.2 cyc/deg is already a fairly low ~0.8 Hz temporal frequency; a true "motion" localizer more commonly pushes temporal frequency up rather than down).
   - If you'd rather stay strictly faithful to the published MT localizer, the paper doesn't specify a different spatial frequency for it, so leaving `stim_cpd = 0.2` (same as scotopic) and `speed_dps = 4` is defensible and literature-consistent — the *moving-vs-stationary contrast*, not the specific spatial frequency, is what's doing the localizing work in this paradigm.

4. **Orientation handling.** The published motion localizer doesn't step through orientations in the same "one new orientation every block" way as the thin-column/scotopic localizer — it's just moving-vs-stationary. You can keep a single fixed orientation (or randomize orientation across motion/stationary block pairs) rather than the current 45°-per-block increment; the orientation manipulation isn't part of what isolates motion sensitivity here.

5. **Block timing is not fully specified in the source paper for this particular localizer** (it only reports scan-level volume counts, not block durations for the moving/stationary contrast). Given the same paper's thin-column localizer uses 24 s stimulus blocks with 12 s uniform-gray pre/post padding, and the current script's 16 s blocks are already a reasonable fMRI block length, a defensible design is: alternate 16 s `moving` / 16 s `stationary` blocks (drop the 16 s blank between every block, or keep occasional blank/baseline blocks for GLM baseline estimation), with a 12–16 s uniform gray field at run start/end. This isn't a value taken directly from the paper — flag it if precision matters for replication.

6. **ROI/analysis note (outside this script):** MT itself should be defined from the moving > stationary contrast specifically in medial temporal sulcus, excluding other motion-responsive patches (V3A, IPS, MST-like) from the "thick-type column" ROI, per the paper's Methods.

## Summary table

| Parameter | Current script (scotopic control) | Photopic motion/MT localizer |
|---|---|---|
| Light level | Scotopic (dark-adapted, ND-filtered) | Photopic (~52 cd/m², normal display) |
| Core contrast | Grating (varying orientation) vs. blank | **Moving grating vs. stationary (static) grating** |
| Spatial frequency | 0.2 cyc/deg (chosen to drive thick + thin equally) | 0.2 cyc/deg is literature-defensible; lower (e.g. 0.1–0.27 cyc/deg) biases more toward M/motion |
| Speed | 4°/s, direction reversed every 6 s | Same is fine; not the manipulation of interest |
| Orientation | Steps +45° per block (7 blocks) | Not load-bearing for this contrast; can fix or randomize |
| Block structure | 16 s stim / 16 s blank × 7, 16 s initial blank (240 s total) | Not explicitly specified in source; suggest alternating 16 s moving/16 s stationary blocks with periodic blank baseline |

## Sources

- [Scotopic Vision Is Selectively Processed in Thick-Type Columns in Human Extrastriate Cortex (Tootell & Nasr, 2021, Cerebral Cortex)](https://academic.oup.com/cercor/article/31/2/1163/5929822)
- [PDF mirror of the above](https://mesovision.martinos.org/wp-content/uploads/2020/10/Tootell-Nasr-2020-Scotopic-Vision-is-Selectively-Processed-in-Thick-Type-Columns-in-Human-Extrastriate-Cortex.pdf)
- [Columnar Segregation of Magnocellular and Parvocellular Streams in Human Extrastriate Cortex (Tootell & Nasr, 2017, J Neurosci)](https://www.jneurosci.org/content/37/33/8014)
- [PDF mirror of the above](https://mesovision.martinos.org/wp-content/uploads/2020/09/Tootell-Nasr-2017-Columnar-segregation-of-magnocellular-and-parvocellular-streams-in-human-extrastriate-cortex.pdf)
- [Interdigitated Color- and Disparity-Selective Columns within Human Visual Cortical Areas V2 and V3 (Nasr, Polimeni & Tootell, 2016, J Neurosci)](https://pubmed.ncbi.nlm.nih.gov/26865609/)
