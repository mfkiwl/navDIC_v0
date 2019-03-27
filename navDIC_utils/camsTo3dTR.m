function PtsApp = camsTo3dTR(hd, MovPts, Pts)

nbCam = length(hd.Cameras) ;
Cam = [] ;

for i = 1:nbCam
    Cam(i) = hd.Cameras(i).Properties ; 
    dz0(i) = ( Pts(:,:,cocam(i)) - Pts(1,:,cocam(i)) ) *...
        [dot(hd.Cameras(cocam(i)).Properties.X,hd.Cameras(i).Properties.Z);...
        dot(hd.Cameras(cocam(i)).Properties.Y,hd.Cameras(i).Properties.Z); 0] ;
end

movPtsCor(:,:) = ( ones(size(MovPts(:,:,i))) + repmat(dz,[1 1]) / hd.Cameras(i).Properties.do ) .* MovPts(:,:,i) ;

PtsApp = zeros(size(Pts,1), 3, nbCam) ;
    
for j = 1:length(Cam)
    for i = 1 : size(MovPts,1)
        PtsApp(i,:,j) = [ Cam(j).do / Cam(j).fx * ( MovPts(i,1,j) - Cam(j).px / 2 ) ,...
                    Cam(j).do / Cam(j).fy * ( MovPts(i,2,j) - Cam(j).py / 2 ) , Cam(j).do ] ;
    end
end


end
