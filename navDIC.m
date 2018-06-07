function navDIC()
        
% ===================================================================================================================    
% MAIN FUNCTION
% ===================================================================================================================
    
    % DEFAULT VALUES
        navDICTag = 'navDIC' ;
        defaultFrameRate = 1 ; % Hz
        maximumFrameRate = 25 ; % Hz
        
    % Is navDIC already running ?
        navDICFigs = findobj(groot,'tag',navDICTag) ;
        % If YES, prompt figures to Foreground
            if ~isempty(navDICFigs)
                navDICOnTop() ;
                return ;
            end

    % Initialization of handles (type "global hd" in cmd to remote debugging access)
        global hd
        hd = [] ; % Shared handles
        hd.initCompleted = false ;
        hd.navDICTag = navDICTag ;
        hd.debug = false ;
        % Directories
            % navDic folder
                [hd.RootPath,~,~] = fileparts(which('navDIC.m')) ;
            % Working Directory
                hd.WorkDir = [] ;
        % DEVICES
            % Cameras
                hd.Cameras = [] ;
            % DAQInputs
                hd.DAQInputs = [] ;
        % DATA
            initHandleData(false)
            hd.FrameRate = defaultFrameRate ;
        % PROCESSING
            % DIC
                hd.Seeds = [] ;
            % Previews
                hd.Previews = [] ;
        % TIMER
            hd.TIMER = timer('ExecutionMode','FixedRate'...
                            ,'Period',1/defaultFrameRate ...
                            ,'TimerFcn',@(src,evt)timerFunction()...
                            ) ;
        % Initialization completed
            hd.initCompleted = true ;
        
    % No changes since last Save
        hd.hasChangedSinceLastSave = false ;
        
    % Init the Main Toolbar
        % Graphical parameters
            infosTxtHeight = 16 ; % Pixels
            frameSliderWidth = .3 ; % relative to toolbar size
        % Constructor
            initToolBar() ;
        
        
        

        
        
% ===================================================================================================================    
% UTIL FUNCTIONS
% ===================================================================================================================

% FUNCTION EXECUTED BY THE TIMER TO TAKE A SHOT
    function timerFunction()
        % Set toolbar in red
            hd.ToolBar.infosTxt.BackgroundColor = [1 0.3 0.3] ;
            drawnow ;
        % MAIN FUNCTION
            % Add a frame
                hd.nFrames = hd.nFrames+1 ;
                hd.CurrentFrame = hd.nFrames ;
            % Capture
                disp('----- Capture time -----') ;
                t = tic ;
                % Time
                    hd.TimeLine(hd.nFrames,:) = clock() ;
                    tclock = toc(t) ;
                    disp(['   Clock : ' num2str(tclock*1000,'%.1f'),' ms']) ;
                % Images
                    hd = captureCameras(hd) ;
                    tcams = toc(t)-tclock ;
                    disp(['   Cameras : ' num2str(tcams*1000,'%.1f'),' ms']) ;
                % Inputs
                    hd = captureInputs(hd) ;
                    tinputs = toc(t)-tclock-tcams ;
                    disp(['   Inputs : ' num2str(tinputs*1000,'%.1f'),' ms']) ;
                disp(['Total : ' num2str(toc(t)*1000,'%.1f'),' ms']) ;
                disp('------------------------') ;
                disp('') ;
            % Save Acquired Data
                hd = saveCurrentSetup(hd) ;
            % Processing
                % DIC
                hd = updateDIC(hd) ;
            % Previews
                hd = updateAllPreviews(hd) ;
        % Update Infos
            pause(0.005) ;
            updateToolbar() ;
        % Reset toolbar Color
            hd.ToolBar.infosTxt.BackgroundColor = hd.ToolBar.infosTxt.UserData.DefaultBackgroundColor ;
    end

% CLEAR DATA IN HANDLES
    function initHandleData(confirm)
        % If needed, answer the user to confirm
            if confirm
                answer = questdlg('DO YOU WANT TO CLEAR THE DATA ACQUIRED PREVIOUSLY ?','Clearing Data','Yes','No','No') ;
                if isempty(answer) ; return ; end
                if strcmp(answer,'No') ; return ; end
            end
        % RESET
            % Frames
                hd.nFrames = 0 ;
                hd.CurrentFrame = 0 ;
            % Time
                hd.TimeLine = [] ;
            % Images
                hd.Images = {} ;
            % Inputs
                hd.InputData = [] ;
        % Update Infos
            if hd.initCompleted 
                updateToolbar() ; 
                hd = updateAllPreviews(hd) ;
            end
    end

% UPDATE INFOS TEXT
    function updateToolbar()
        % Is There any inputs ?
            nIn = 0 ; if ~isempty(hd.DAQInputs) ; nIn = length(hd.DAQInputs.Inputs) ; end
        % Infos String
            strInfos = [] ;
            strInfos = [strInfos,' ',num2str(length(hd.Cameras)),' Cameras'] ;
            strInfos = [strInfos,' | ',num2str(nIn),' DAQ.Inputs'] ;
            strInfos = [strInfos,' | ',num2str(length(hd.Seeds)),' DIC.Seeds'] ;
            strInfos = [strInfos,' | ',num2str(length(hd.Previews)),' Previews'] ;
            strInfos = [strInfos,' | Frame ',num2str(hd.CurrentFrame),'/',num2str(hd.nFrames)] ;
            hd.ToolBar.infosTxt.String = strInfos ;
        % Frame Slider
            minVal = min(1,hd.nFrames) ;
            maxVal = max(hd.nFrames,1) ;
            hd.ToolBar.frameSlider.Min = minVal ;
            hd.ToolBar.frameSlider.Max = maxVal ;
            hd.ToolBar.frameSlider.Value = min([max(minVal,hd.CurrentFrame),maxVal,hd.nFrames]) ;
            minSliderStep = 1/max(2,hd.nFrames) ;
            maxSliderStep = max(minSliderStep,1/10) ;
            hd.ToolBar.frameSlider.SliderStep = [minSliderStep maxSliderStep] ;
            % Enable or not
                if hd.nFrames>1 %&& strcmp(hd.TIMER.Running,'off') 
                    hd.ToolBar.frameSlider.Enable = 'on' ;
                else
                    hd.ToolBar.frameSlider.Enable = 'off' ;
                end
        % Menus
            updateMainMenu()
    end

% CHANGE THE FRAME FOR PREVIEW
    function changeFrame()
        hd.ToolBar.frameSlider.Value = round(hd.ToolBar.frameSlider.Value) ;
        if hd.CurrentFrame==hd.ToolBar.frameSlider.Value ; return ; end
        hd.CurrentFrame = hd.ToolBar.frameSlider.Value ;
        hd = updateAllPreviews(hd) ;
        updateToolbar() ;
    end

% SWITCH IN DEBUG MODE
    function debugMode()
        hd.debug = true ;
        % Enable all Menus
            set(findobj(hd.ToolBar.fig,'type','uimenu'),'enable','on') ;
    end

% SET THE WORKING DIRECTORY
    function setPath(src,varargin)
        % Open a dialog box if needed
            if strcmp(src,'menu')
                [file,path] = uiputfile('*','SELECT THE WORKING DIRECTORY, COMMON NAME AND IMAGE FORMAT','img.tif') ;
                if file ==0 ; return ; end
                [~,file,ext] = fileparts(file) ;
                varargin = {path,file,ext} ;
            end
        % Update Work. Dir. Infos
            hd.WorkDir = [] ;
            hd.WorkDir.Path = varargin{1} ;
            hd.WorkDir.CommonName = varargin{2} ;
            hd.WorkDir.ImagesExtension = varargin{3} ;
        % Display infos
            disp('WORKING DIRECTORY : ') ;
            disp(hd.WorkDir) ;
    end

% OPEN A SETUP
    function openSetup
        % Select the folder of an existing setup
            [path] = uigetdir('SELECT THE DIRECTORY OF A SAVED SETUP') ;
            if path==0 ; return ; end
        % Load the setup
            setup = loadSetup(path) ;
        % Set the WorkDir
            setPath('open',setup.Path,setup.CommonName,setup.ImagesExtension) ;
        % Update handles and displays it
            hd.Images = setup.Images ;
            hd.ROI = setup.ROI ;
            hd.DIC = setup.DIC ;
            hd.Data = setup.Data ;
            clc ; disp('CURRENT SETUP HANDLES : ') ; display(hd) ;
        % Update the Main Menu Bar
            updateMainMenu() ;
    end

% SAVE THE SETUP DATA
    function saveSetupData()
        hd = saveAllSetupData(hd) ;
    end


% START CONTINUOUS SETUP
    function startContinuous()
        hd.ToolBar.frameSlider.Enable = 'off' ;
        hd.ToolBar.MainMenu.startStop.Label = 'STOP' ;
        hd.ToolBar.MainMenu.startStop.Callback = @(src,evt)stopContinuous ;
        start(hd.TIMER) ;
    end

% STOP CONTINUOUS SETUP
    function stopContinuous() 
        if strcmp(hd.TIMER.Running,'on')
            stop(hd.TIMER) ;
            while strcmp(hd.TIMER.Running,'on') ; end
        end  
        hd.ToolBar.MainMenu.startStop.Label = 'START' ;
        hd.ToolBar.MainMenu.startStop.Callback = @(src,evt)startContinuous ;
    end

% TAKE A SINGLE SHOT AND PROCESS
    function singleShot()
        if strcmp(hd.TIMER.Running,'on') ; return ; end
        timerFunction() ;     
    end


% SET THE CAMERAS
    function manageCameras
        % Stop all cameras
            hd = stopAllCameras(hd) ;
        % Open the manageMultiCameras Tool
            [hd.Cameras,camsHasChanged] = manageMultiCameras(hd.Cameras) ;
        % Re-start all cameras
            hd = startAllCameras(hd) ;
        % If nothing changed...
            if ~camsHasChanged ; return ; end
        % Ask to clear the data
            initHandleData(true) ;
        % Update Infos
            updateToolbar() ;
    end

% PREVIEW A CAMERA
    function camPreview
        prev = navDICCameraPreview(hd) ;
        if prev.isValid
            hd.Previews{end+1} = prev ;
        end
    end

% SET THE EXTERNAL INPUTS
    function manageInputs
        % Open the manageDAQInputs Tool
            [hd.DAQInputs,inputsHasChanged] = manageDAQInputs(hd.DAQInputs) ;
            if ~inputsHasChanged ; return ; end
        % Ask to clear the data
            initHandleData(true) ;
        % Update Infos
            updateToolbar() ;
    end

% SET THE EXTERNAL INPUTS
    function inputPreview
    end

% SET THE FRAME RATE
    function setFrameRate()
        frameRate = evalMaxFrameRate() ;
        if isempty(frameRate)
            frameRate = inputdlg('Set the Frame Rate (Hz)','navDIC Frame Rate',1,{num2str(hd.FrameRate)}) ;
            if isempty(frameRate) ; return ; end
            frameRate = str2num(frameRate{1}) ;
            if frameRate>maximumFrameRate 
                errordlg(['Maximum Frame Rate is ',num2str(maximumFrameRate),' Hz']) ;
                return ;
            end
        end
        hd.FrameRate = frameRate ;
        hd.TIMER.Period = round(1/frameRate*1000)/1000 ; % millisecond precision
    end

% EVALUATE THE MAXIMUM FRAME RATE
    function avisedFR = evalMaxFrameRate()
        % Evaluate the maximumFrameRate by iterating the global timerFunction
            evalTime = 1 ; % seconds
        % Backup the config
            nFrames = hd.nFrames ;
            currentFrame = hd.CurrentFrame ;
        % Stop the timer
            stopContinuous() ;
        % Execute it while it last less than evalTime
            t = tic ;
            it = 0 ;
            while toc(t)<evalTime
                timerFunction() ;
                it = it+1 ;
            end
        % Evaluate the maxFrameRate
            maxFR = it/toc(t) ;
            avisedFR = min(0.8*maxFR,maximumFrameRate) ;
        % Reset all data OK
            hd.nFrames = nFrames ;
            hd.CurrentFrame = currentFrame ;
            hd.TimeLine = hd.TimeLine(1:nFrames,:) ;
            if nFrames>0 
                if ~isempty(hd.Cameras) ; hd.Images = hd.Images(1:nFrames) ; end
                if ~isempty(hd.DAQInputs) ; hd.InputData = hd.InputData(1:nFrames,:) ; end
            else
                hd.Images = {} ;
                hd.InputData = [] ;
            end
        % Update toolbar and previews ;
            updateToolbar() ;
            hd = updateAllPreviews(hd) ;
        % Prompt the maxFrameRate
            answer = questdlg({['The Maximum Frame Rate is ',num2str(maxFR,'%.2f'),' Hz'],...
                                ['Set the Frame Rate to ',num2str(avisedFR,'%.2f'),' Hz ?']},'Evaluated Frame rate','Yes','No','No') ;
            if strcmp(answer,'No')
                avisedFR = [] ;
            end
            
    end

% SET THE FRAME RATE
    function setImageSaving
    end

% MANAGE DIC ZONES
    function manageDICZones
        hd = manageDICSeeds(hd) ;
        % Update Infos
            updateToolbar() ;
    end

% PREVIEW AN INDIVIDUAL DIC SEED
    function previewSeed()
        if isempty(hd.Seeds) ; return ; end
        prev = navDIC2DSeedPreview(hd) ;
        if prev.isValid
            hd.Previews{end+1} = prev ;
        end
    end

% COMPUTE NON-COMPUTED DIC ZONES
    function computeDIC
        disp('computeDIC')
    end

% COMPUTE ALL DIC ZONES
    function computeAllDIC
        disp('computeAllDIC')
        hd = updateDIC(hd) ;
    end

% MANAGE AXES
    function manageViews
    end

% AUTO LAYOUT
    function autoLayout
    end



        
% ===================================================================================================================    
% GRAPHICAL FUNCTIONS
% ===================================================================================================================

% BRING ALL NAVDIC FIGURES TO FRONT
    function navDICOnTop()
        disp('tofront') ;
        navDICFigs = findobj(groot,'tag',navDICTag) ;
        if ~isempty(navDICFigs)
            for f = 1:length(navDICFigs)
                figure(navDICFigs(f)) ;
            end
        end
    end

% CREATES THE MAIN FIGURE FOR MENU AND TOOLBAR
    function initToolBar()
       % Figure creation
           screenPos = get(groot,'monitorpositions') ;
           hd.ToolBar.fig = figure('Name','navDIC v0.0',...
                                    'toolbar','none',...
                                    'menubar','none',...
                                    'outerposition',screenPos(end,:),...
                                    'dockcontrols','off',...
                                    'NumberTitle','off',...
                                    'Visible','off',...
                                    'tag',navDICTag...
                                    ) ;
           hd.ToolBar.fig.ButtonDownFcn = @(src,evt)navDICOnTop() ;
       % Close Callback
        hd.ToolBar.fig.CloseRequestFcn = @(src,evt)closeAll() ;
       % Add the main menu
           addMainMenu() ;
           updateMainMenu() ;
       % Put The toolbar at the top of the screen
           drawnow ; % I don't know why, but i'm forced to draw here...
           hd.ToolBar.fig.Position(4) = infosTxtHeight ;
           hd.ToolBar.fig.OuterPosition(2) = screenPos(4) - hd.ToolBar.fig.OuterPosition(4) ;
           drawnow ;
       % Init the Info textbox
           hd.ToolBar.infosTxt = uicontrol('style','text'...
                                            ,'fontname','Consolas'...
                                            ,'string',''...
                                            ,'units','normalized'...
                                            ,'position',[0 0 1 1]...
                                            ,'fontunits','pixels'...
                                            ,'fontsize',0.8*infosTxtHeight...
                                            ,'horizontalalignment','left'...
                                            ) ;
           hd.ToolBar.infosTxt.UserData.DefaultBackgroundColor = hd.ToolBar.infosTxt.BackgroundColor ;
       % Init the step Slider
           hd.ToolBar.frameSlider = uicontrol('style','slider'...
                                            ,'units','normalized'...
                                            ,'enable','off'...
                                            ,'position',[1-frameSliderWidth 0 frameSliderWidth 1]...
                                            ) ;
           % Listener for continuous slider
                addlistener(hd.ToolBar.frameSlider, 'Value', 'PostSet',@(src,evt)changeFrame());
        % MAKE THE FIGURE VISIBLE
            drawnow ;
            hd.ToolBar.fig.Visible = 'on' ;
       % Add shortcuts buttons
            addButtons() ;
            setMainMenuShortcuts() ;
            drawnow ;
    end


% BUILD THE MAIN MENU
    function addMainMenu()
        
        % NAVDIC ----------------------------------------------------------
           hd.ToolBar.MainMenu.navDIC = uimenu(hd.ToolBar.fig,'Label',navDICTag) ;
           % Open a setup
                hd.ToolBar.MainMenu.openSetup = uimenu(hd.ToolBar.MainMenu.navDIC, ...
                                                        'Label','Open a Setup', ...
                                                        'callback',@(src,evt)openSetup) ;
           % Set working dir
                hd.ToolBar.MainMenu.setDir = uimenu(hd.ToolBar.MainMenu.navDIC,...
                                                        'Label','Set the Working Directory', ...
                                                        'callback',@(src,evt)setPath('menu')) ;
           % Save All Data
                hd.ToolBar.MainMenu.saveSetupData = uimenu(hd.ToolBar.MainMenu.navDIC,...
                                                        'Label','Save the Setup Data', ...
                                                        'callback',@(src,evt)saveSetupData()) ;
           % Frame Rate
                hd.ToolBar.MainMenu.frameRate = uimenu(hd.ToolBar.MainMenu.navDIC,...
                                                        'Label','Frame Rate', ...
                                                        ...'Enable','off', ...
                                                        'Separator','on', ...
                                                        'callback',@(src,evt)setFrameRate) ;
           % Image Saving
                hd.ToolBar.MainMenu.saveImages = uimenu(hd.ToolBar.MainMenu.navDIC,...
                                                        'Label','Save Images', ...
                                                        ...'Enable','off', ...
                                                        'Checked','on', ...
                                                        'callback',@(src,evt)setImageSaving) ;
                
           % Start and Stop navDIC
                hd.ToolBar.MainMenu.startStop = uimenu(hd.ToolBar.MainMenu.navDIC,...
                                                        'Label','START', ...
                                                        ...'Enable','off', ...
                                                        'Separator','on', ...
                                                        'callback',@(src,evt)startContinuous) ;
                
           % Snapshot
                hd.ToolBar.MainMenu.singleShot = uimenu(hd.ToolBar.MainMenu.navDIC,...
                                                        'Label','Take a Snapshot', ...
                                                        ...'Enable','off', ...
                                                        'callback',@(src,evt)singleShot) ;
                
           % Snapshot
                hd.ToolBar.MainMenu.reset = uimenu(hd.ToolBar.MainMenu.navDIC,...
                                                        'Label','RESET', ...
                                                        'Separator','on', ...
                                                        'callback',@(src,evt)initHandleData(true)) ;
                
        % CAMERAS ---------------------------------------------------------
           hd.ToolBar.MainMenu.cameras = uimenu(hd.ToolBar.fig,'Label','Cameras') ;
           % Set Cameras
                hd.ToolBar.MainMenu.manageCameras = uimenu(hd.ToolBar.MainMenu.cameras,...
                                                        'Label','Manage Cameras', ...
                                                        'callback',@(src,evt)manageCameras) ;
           % Preview a Camera
                hd.ToolBar.MainMenu.camPreview = uimenu(hd.ToolBar.MainMenu.cameras,...
                                                        'Label','Preview a Camera', ...
                                                        ...'Enable','off', ...
                                                        'callback',@(src,evt)camPreview) ;
                
        % EXTERNAL INPUTS -------------------------------------------------
           hd.ToolBar.MainMenu.extInputs = uimenu(hd.ToolBar.fig,'Label','Inputs') ;
           % Set Inputs
                hd.ToolBar.MainMenu.manageInputs = uimenu(hd.ToolBar.MainMenu.extInputs,...
                                                        'Label','Manage Inputs', ...
                                                        'callback',@(src,evt)manageInputs) ;
           % Preview an Input
                hd.ToolBar.MainMenu.inputPreview = uimenu(hd.ToolBar.MainMenu.extInputs,...
                                                        'Label','Preview an Input', ...
                                                        ...'Enable','off', ...
                                                        'callback',@(src,evt)inputPreview) ;
                
        % DIC -------------------------------------------------
           hd.ToolBar.MainMenu.DIC = uimenu(hd.ToolBar.fig,'Label','DIC','Enable','off') ;
           % Manage DIC Seeds
                hd.ToolBar.MainMenu.manageDICZones = uimenu(hd.ToolBar.MainMenu.DIC,...
                                                        'Label','Manage DIC Seeds', ...
                                                        'callback',@(src,evt)manageDICZones) ;
           % Preview a DIC Seed
                hd.ToolBar.MainMenu.previewSeed = uimenu(hd.ToolBar.MainMenu.DIC,...
                                                        'Label','Preview a Seed', ...
                                                        'callback',@(src,evt)previewSeed()) ;
           % Compute DIC
                hd.ToolBar.MainMenu.computeDIC = uimenu(hd.ToolBar.MainMenu.DIC,...
                                                        'Label','Compute DIC'...
                                                        ...,'Enable','off'...
                                                        ,'Separator','on'...
                                                        ) ;
               % Only Non-Computed Zones
                    hd.ToolBar.MainMenu.computeSomeDIC = uimenu(hd.ToolBar.MainMenu.computeDIC,...
                                                            'Label','Non-Computed Zones Only', ...
                                                            'callback',@(src,evt)computeDIC) ;
               % All Zones
                    hd.ToolBar.MainMenu.computeAllDIC = uimenu(hd.ToolBar.MainMenu.computeDIC,...
                                                            'Label','All Zones', ...
                                                            'callback',@(src,evt)computeAllDIC) ;
                
        % VIEWS -------------------------------------------------
           hd.ToolBar.MainMenu.views = uimenu(hd.ToolBar.fig,'Label','Views');%,'Enable','off') ;
           % Manage Axes
                hd.ToolBar.MainMenu.manageViews = uimenu(hd.ToolBar.MainMenu.views,...
                                                        'Label','Manage Views', ...
                                                        'callback',@(src,evt)manageViews) ;
           % Auto Layout
                hd.ToolBar.MainMenu.autoLayout = uimenu(hd.ToolBar.MainMenu.views,...
                                                        'Label','Auto Layout', ...
                                                        ...'Enable','off', ...
                                                        'callback',@(src,evt)autoLayout) ;
                
        % HELP -------------------------------------------------
           hd.ToolBar.MainMenu.help = uimenu(hd.ToolBar.fig,'Label','?');%,'Enable','off') ;
           % Manage Axes
                hd.ToolBar.MainMenu.about = uimenu(hd.ToolBar.MainMenu.help,...
                                                        'Label','About', ...
                                                        'callback',@(src,evt){}) ;
           % DebugMode
                hd.ToolBar.MainMenu.debugMode = uimenu(hd.ToolBar.MainMenu.help,...
                                                        'Label','Debug', ...
                                                        ...'Enable','on', ...
                                                        'callback',@(src,evt)debugMode) ;
                                                    
                                                    
    end

% SET THE MAIN TOOLBAR SHORTCUTS
    function setMainMenuShortcuts()
        % Define Shortcuts
            shortcuts = {'Open a Setup','shift O'; ...
                         'Set the Working Directory','shift S'; ...
                         'START','shift ENTER'; ...
                         'Take a Snapshot','shift SPACE'; ...
                         } ;
        % The Java container objects has extended possibilities for shortcuts
        % Get java Objects linked to the main menu
            jHandles = findjobj(hd.ToolBar.fig,'class','menu') ;
            jHandles = jHandles(2:end) ; % Delete the first global handle
        % Get jLabels
            jHandlesLabels = jHandles(:).get('Text') ;
        % Set "accelerators" (or shortcuts)
            for s = 1:size(shortcuts,1)
                idHandle = ismember(jHandlesLabels,{shortcuts{s,1}}) ;
                if any(idHandle)
                    jAccelerator = javax.swing.KeyStroke.getKeyStroke(shortcuts{s,2}) ;
                    jHandles(idHandle).setAccelerator(jAccelerator);
                end
            end
    end


% UPDATE THE MAIN MENU
    function updateMainMenu()
        % Is There any inputs ?
            nIn = 0 ; if ~isempty(hd.DAQInputs) ; nIn = length(hd.DAQInputs.Inputs) ; end
        % Debug blocks the mainmenu enable behavior
            if ~hd.debug
                % Data acquisition
                    if ~isempty(hd.Cameras) || nIn~=0
                        hd.ToolBar.MainMenu.startStop.Enable = 'on' ;
                        hd.ToolBar.MainMenu.singleShot.Enable = 'on' ;
                        hd.ToolBar.MainMenu.frameRate.Enable = 'on' ;
                        hd.ToolBar.MainMenu.saveImages.Enable = 'on' ;
                    else
                        hd.ToolBar.MainMenu.startStop.Enable = 'off' ;
                        hd.ToolBar.MainMenu.singleShot.Enable = 'off' ;
                        hd.ToolBar.MainMenu.frameRate.Enable = 'off' ;
                        hd.ToolBar.MainMenu.saveImages.Enable = 'off' ;
                    end
                % Cameras
                    if ~isempty(hd.Cameras)
                        hd.ToolBar.MainMenu.camPreview.Enable = 'on' ;
                        hd.ToolBar.MainMenu.DIC.Enable = 'on' ;
                    else
                        hd.ToolBar.MainMenu.camPreview.Enable = 'off' ;
                        hd.ToolBar.MainMenu.DIC.Enable = 'off' ;
                    end
                % Inputs
                    if nIn~=0
                        hd.ToolBar.MainMenu.inputPreview.Enable = 'on' ;
                    else
                        hd.ToolBar.MainMenu.inputPreview.Enable = 'off' ;
                    end
            end
    end


% ADDS BUTTONS TOOLBAR
    function addButtons()
    end


% CLOSE THE PROGRAM
    function closeAll()
        % Ask the user about LOOSING INFO
            if exist('hd','var') && hd.hasChangedSinceLastSave
                button = questdlg('Close the navDIC ? All data will be lost.','CLOSE REQUEST','Yes','No','No') ;
                switch button
                    case 'No' % Stop !
                        return ;
                    case 'Yes' % Continue
                end
            end
        % STOP THE TIMER
            stop(hd.TIMER) ;
            while strcmp(hd.TIMER.Running,'on') ; end
        % STOP ALL CAMERAS
            hd = stopAllCameras(hd) ;
        % Close all figures belonging to navDIC 
            hd.ToolBar.fig.CloseRequestFcn = @(src,evt)closereq ;
            figs_navDIC = findobj(0,'tag',navDICTag) ;
            delete(figs_navDIC) ;
            clear('hd') ;
    end

end






















        
% ===================================================================================================================    
% RETIRED CODE FUNCTIONS
% ===================================================================================================================


% FUNCTIONS ----------------------------------------------------
% % SET THE ROI
%     function setTheROI
%     end
% 
% % CROP WITH ROI
%     function cropWithROI
%     end
% 
% % SET CROPPING MARGINS
%     function setCroppingMargins
%     end


    

% TOOLBAR MENUS ----------------------------------------------------
%         % ROI -------------------------------------------------
%            hd.ToolBar.MainMenu.ROI = uimenu(hd.ToolBar.fig,'Label','ROI');%,'Enable','off') ;
%            % Set the ROI
%                 hd.ToolBar.MainMenu.setROI = uimenu(hd.ToolBar.MainMenu.ROI,...
%                                                         'Label','Set the Region Of Interest', ...
%                                                         'callback',@(src,evt)setTheROI) ;
%            % Separator -------------
%                 uimenu(hd.ToolBar.MainMenu.ROI,'Label','-------------------','Enable','off') ;
%            % Crop With ROI
%                 hd.ToolBar.MainMenu.cropWithROI = uimenu(hd.ToolBar.MainMenu.ROI,...
%                                                         'Label','Crop Images with the ROI', ...
%                                                         'Checked','on', ...
%                                                         'Enable','off', ...
%                                                         'callback',@(src,evt)cropWithROI) ;
%            % Crop Margins
%                 hd.ToolBar.MainMenu.cropMargins = uimenu(hd.ToolBar.MainMenu.ROI,...
%                                                         'Label','Cropping Margins', ...
%                                                         'Enable','off', ...
%                                                         'callback',@(src,evt)setCroppingMargins) ;