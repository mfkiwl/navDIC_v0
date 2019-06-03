if 1 % USE THIS TO GO DIRECTLY TO DIC

    % CLEAN WORKSPACE
        clc
        global hd
        clearvars -except hd

    % INITIALIZATION PARAMETERS
        camID = 1 ;
        seedNumber = 2 ;
        frames = '[1,276:1:302]' ; % Frames taken for DIC (allows decimation)
        dicDir = 1 ; % DIC running direction ('forward=1' or 'backward=-1')
        refFrame = 'first' ; % Reference image ('first' , 'last' or number)
        averagePreviousFrames = true ; % Ref frame is the average of the previous/next ones in forward/backward modes
        normToImageClassRange = true ; % Normalize images to their dataclass range
        timeMeanLength = 0 ; % Time averaging of images
        strainCriterion = 'full' ; % strain gradient penalization: 'full' or 'normal'
        codeProfile = false ; % Code timing

    % Perform Initialization
        globalDIC_01_LoadFrames ;
        globalDIC_02_0_ProcessSeed ;
        globalDIC_03_Kernels ;
        globalDIC_04_StrainCriterion
        
end % END OF INITIALIZATION
    
%% PERFORM DIC !

% PARAMETERS
    % Displacement guess
        startWithNavDICPositions = true ; % Use a preceding computation as guess
        addPreviousVelocity = true ; % When possible ans no navDIC results available (or not used), add the previous motion as convergence help
    % Image Warping
        imWarpInterpOrder = 'cubic' ;
    % Image difference criterion
        diffCriterion = ... 'Diff' ... Simple difference
                        ... 'ZM_Diff' ... Zero-mean difference
                         'ZM_N_Diff' ... Normalized Zero-mean difference
                         ;
    % Geometry validation criteria
        cullOutOfFrame = true ; % Cull out of frame points
        localWEIGHT = INSIDE ; % MAPPING ; % For local averaging and difference image moments computations
        minCorrCoeff = .0 ; % Below this, elements are culled
        alwaysCheckCorrCoeff = false ; % Check corr. coeffs at each iteration or only after convergence ?
    % Regularization
        beta = 1*1e3 ; % Strain gradient penalisation coefficient
    % Convergence Criteria
        maxIt = 100 ; % Maximum number of Newton-Raphson iterations
        minNorm = 5e-4 ; % Maximum displacement of a node
    % Plotting
        plotRate = 0 ; % Plot Refresh Frequency 
        plotEachIteration = true ; % Plot at every iteration (without necessary pausing, bypass plotRate)
        plotEachFrame = true ; % Plot at every Frame end (without necessary pausing, bypass plotRate)
        pauseAtPlot = false ; % Pause at each iteration for debugging
    % Watch CPU 
        codeProfile = false ;
    
    
% RUN DIC
    % Initialize
        globalDIC_05_InitDIC ;
    % Run
        if codeProfile ; profile on ; end
        globalDIC_06_PerformDIC ;
        if codeProfile; profile viewer ; profile off ; end
    % Process
        globalDIC_07_AfterDIC ;
    % Send to navDIC
        globalDIC_08_TOnavDIC ;

    