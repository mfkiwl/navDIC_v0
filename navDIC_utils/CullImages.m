%% CULL IMAGES IN THE COLLECTION
clearvars -except hd
global hd
hd_bkp = hd ;


%% 2020.07.03 FirstWall 
idx = round(0:4.345:955)+34 ; 1:numel(hd_bkp.Images{end}) ;
idx([3 17 20 23 46 49 52 75 81 101 107 130 133 139 159 165 188 191 217]) = ...
    [42 103 116 129 229 242 255 355 381 468 494 594 607 633 720 746 846 859 972] ;

%%
idx = 1:2:hd_bkp.nFrames ;

%%
idx = 2:hd_bkp.nFrames ;

%%
for cam = 1:numel(hd_bkp.Images) ; hd.Images{cam} = hd_bkp.Images{cam}(idx) ; end
for ss = 1:numel(hd_bkp.Seeds)
    hd.Seeds(ss) = copy(hd_bkp.Seeds(ss)) ;
    hd.Seeds(ss).MovingPoints = hd_bkp.Seeds(ss).MovingPoints(:,:,idx) ; 
end
if ~isempty(hd_bkp.TimeLine) ; hd.TimeLine = hd_bkp.TimeLine(idx,:) ; end
if ~isempty(hd_bkp.InputData) ; hd.InputData = hd_bkp.InputData(idx,:) ; end
hd.nFrames = numel(idx) ;

