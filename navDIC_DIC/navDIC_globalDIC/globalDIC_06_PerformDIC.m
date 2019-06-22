%% RUN GLOBAL DIC !

lastPlotTime = tic ;
for ii = dicFrames
    % Init
        it = 0 ;
        outFlag = false ;
        dUo = ones(nNodes,2)*0 ;
    % Import and display current image
        img2i = IMG(:,:,:,ii) ;
        img2 = Smooth(img2i) ;
    % Init Valid Geometry for this frame
        VALID.Nodes(:,ii) = VALID.Nodes(:,ii-dicDir) ;
        VALID.Elems(:,ii) = VALID.Elems(:,ii-dicDir) ;
        VALID.Edges(:,ii) = VALID.Edges(:,ii-dicDir) ;
        VALID.NakedEdges(:,ii) = VALID.NakedEdges(:,ii-dicDir) ;
    % First Guess for the displacement if needed
        if ~useNavDICXn(ii) || all(isnan(Xn(:,1,ii)))
            % Take the previously computed frame
                Xn(:,:,ii) = Xn(:,:,ii-dicDir) ;
            % Add the previous "speed" as convergence help
                if addPreviousVelocity && abs(refFrame-ii)>=2
                    Xn(:,:,ii) = Xn(:,:,ii) + (Xn(:,:,ii-dicDir)-Xn(:,:,ii-2*dicDir)) * (frames(ii)-frames(ii-dicDir))/(frames(ii-dicDir)-frames(ii-2*dicDir)) * 1.0 ;
                end
            % Displacement
                Un(:,:,ii) = Xn(:,:,ii) - Nodes ;
        end
    % Newton-Raphson
        RMSE_0 = Inf ;
        while ~outFlag && ~stopBtn.Value
            % VALID GEOMETRY 
                % OUT-OF-FRAME POINTS
                    if cullOutOfFrame
                        VALID.Nodes(:,ii) = VALID.Nodes(:,ii) & Xn(:,1,ii)<nJ+1 & Xn(:,1,ii)>=1 & Xn(:,2,ii)<nI+1 & Xn(:,2,ii)>=1 ;
                    end
                % Elements
                    VALID.Elems(:,ii) = VALID.Elems(:,ii) & sum(tri2nod(VALID.Nodes(:,ii),:),1)'==3 ; % triangles with still their three nodes valid
                % Edges
                    VALID.Edges(:,ii) = VALID.Edges(:,ii) & sum(edg2nod(VALID.Nodes(:,ii),:),1)'==2 ; % edges with still their two ends points valid
                    VALID.NakedEdges(:,ii) = sum(tri2edg(:,VALID.Elems(:,ii)),2)<2 ; % edges with less than two elements valid
                % Nodes
                    VALID.Nodes(:,ii) = VALID.Nodes(:,ii) & sum(tri2nod(:,VALID.Elems(:,ii)),2)>0 ; % nodes must be linked to at least one valid element
                    VALID.Nodes(:,ii) = VALID.Nodes(:,ii) & sum(edg2nod(:,VALID.Edges(:,ii)),2)>0 ; % nodes must be linked to at least one valid edge
                    nVALID = sum(VALID.Nodes(:,ii)) ;
                    if nVALID==0 ; break ; end
                    tri2nod_it = tri2nod(VALID.Nodes(:,ii),VALID.Elems(:,ii)) ;
                    valance_it = tri2nod_it./sum(tri2nod_it,2) ;
                % Valid domain at the pixel level
                    validDomain_it = any(INSIDE(:,VALID.Elems(:,ii)),2) ;
            % PIXEL-WISE DISPLACEMENT AND DIC DOMAIN
                % VALID DIC Domain
                % Compute the displacement 
                    Ui = Un(:,:,ii) ; Ui(~VALID.Nodes(:,ii),:) = 0 ;
                    Up = MAPPING*Ui ;
                % New position of each pixel
                    JJp = JJd+Up(:,1) ;
                    IIp = IId+Up(:,2) ;
                % Cull out-of-frame pixels
                    if ~cullOutOfFrame % pixels can be outside only if Nodes are outside
%                         outOfFrame = IIp<1 | IIp>nI | JJp<1 | JJp>nJ ;
                    end
            % IMAGE WARPING
                % Reduce the interpolation frame
                    iii = floor(min(IIp)):ceil(max(IIp)) ;
                    jjj = floor(min(JJp)):ceil(max(JJp)) ;
                % Warp the image
                    img2v = interp2(JJ(iii,jjj),II(iii,jjj),img2(iii,jjj),JJp,IIp,imWarpInterpOrder) ;
            % IMAGE MOMENTS
                % Select the part of the reference image of interest
                    img1v = img1(indDOMAIN) ;
                % Mean over elements
                    if refImageChanged ; meanImg1 = (WEIGHT'*img1v)./sumWEIGHT ; end
                    meanImg2 = (WEIGHT'*img2v)./sumWEIGHT ;
                % Zero-local-mean on pixels
                    if refImageChanged ; img1m = img1v-WEIGHT*meanImg1 ; end
                    img2m = img2v-WEIGHT*meanImg2 ;
                % Norm over element
                    if refImageChanged ; normImg1 = sqrt(WEIGHT'*(img1m.^2)) ; end
                    normImg2 = sqrt(WEIGHT'*(img2m.^2)) ;
                % Zero-local-mean-normalized images
                    if refImageChanged ; img1mz = img1m./(WEIGHT*normImg1) ; end
                    img2mz = img2m./(WEIGHT*normImg2) ;
            % IMAGE FUNCTIONAL
                switch diffCriterion
                    case 'Diff' % Simple difference
                        diffImg = img1v-img2v ;
                        weight = speye(2*nVALID) ;
                    case 'ZM_Diff' % Zero-mean difference
                        diffImg = img1m-img2m ;
                        weight = speye(2*nVALID) ;
                    case 'ZM_N_Diff' % Normalized Zero-mean difference
                        diffImg = img1mz-img2mz ;
                        switch size(WEIGHT,2)
                            case nNodes
                                ww = 1./normImg1(VALID.Nodes(:,ii)) ;
                            case nElems
                                ww = valance_it*normImg1(VALID.Elems(:,ii)) ;
                        end
                        weight = sparse(1:2*nVALID,1:2*nVALID,[ww;ww]) ;
                end
            % NEWTON-RAPHSON PROCEDURE
                % Recompute Jacobian and Hessian if needed
                    if refImageChanged
                        % Image gradients
                            dImg1_dx = dI_dx(img1) ;
                            dImg1_dy = dI_dy(img1) ;
                        % Jacobian
                            dImg1_da = [...
                                    spdiag(dImg1_dx)*MAPPING ... 
                                    spdiag(dImg1_dy)*MAPPING ... 
                                    ] ;
                        % Hessian
                            Hess = dImg1_da'*dImg1_da ;
                        % No need to compute next time
                            refImageChanged = false ;
                    end
                % Compute the first RMSE derivative
                    dr_da = (dImg1_da(validDomain_it,:)'*diffImg(validDomain_it)) ;
                % Contraint on the SECOND displacement gradient
                    validDOF = [VALID.Nodes(:,ii);VALID.Nodes(:,ii)] ;
                    wCon = ones(1,nVALID) ;
                    switch strainCriterion
                        case 'normal'
                            vEdg = repmat(~VALID.NakedEdges(:,ii),[2 1]) ;
                            vEle = [VALID.Elems(:,ii);VALID.Elems(:,ii);VALID.Elems(:,ii)] ;
                            CONS = B(vEle,validDOF)'*(Ed(vEdg,vEle)'*Ed(vEdg,vEle))*B(vEle,validDOF) ;
                        case 'full'
                            vEdg = repmat(~VALID.NakedEdges(:,ii),[4 1]) ;
                            vEle = [VALID.Elems(:,ii);VALID.Elems(:,ii);VALID.Elems(:,ii);VALID.Elems(:,ii)] ;
                            CONS = G(vEle,validDOF)'*(Ed(vEdg,vEle)'*Ed(vEdg,vEle))*G(vEle,validDOF) ;
                            if strcmp(regCrit,'rel') ; wCon = 1./max(epsTrsh,abs(repmat(valance_it,[1 4])*G(vEle,validDOF)*[Un(VALID.Nodes(:,ii),1,ii);Un(VALID.Nodes(:,ii),2,ii)])) ; end
                    end
                    wCon = sparse(1:2*nVALID,1:2*nVALID,[wCon;wCon]) ;
                % Updating DOFs, X*a=b
                    X = ( ...
                            weight*Hess(validDOF,validDOF)*weight...
                            + beta*wCon*CONS*wCon...
                        ) ; 
                    b = (...
                            weight*dr_da(validDOF)...
                            - beta*wCon*CONS*[Un(VALID.Nodes(:,ii),1,ii);Un(VALID.Nodes(:,ii),2,ii)]...
                        ) ;
                    a = X\b ;
                % Displacement
                    dU = reshape(a,[nVALID 2]) ;
                    Un(VALID.Nodes(:,ii),:,ii) = Un(VALID.Nodes(:,ii),:,ii) + dU ;
                % Positions
                    Xn(:,:,ii) = Nodes + Un(:,:,ii) ;
            % CONVERGENCE CITERIONS
                % Residues Maps
                    resid = abs(diffImg) ;
                    meanSquaredElemResid = ((WEIGHT'*abs(diffImg))) ;
                    corrCoeff = abs(WEIGHT'*(img1mz.*img2mz)) ;
                % Displacement oscillations
                    corr_dU = sum(dUo(validDOF).*dU(:))/(norm(dUo(validDOF))*norm(dU(:))) ;
                    dUo(:) = 0 ; dUo(validDOF) = dU(:) ;
                % Criterions
                    it = it+1 ;
                    %RMSE = norm(diffImg(DOMAIN))/norm(img1(DOMAIN)) ; 
                    normA = max(abs(a)) ; norm(a)/nNodes ;
                % Convergence criterion
                    if it>maxIt ; outFlag = true ; end
                    if normA<minNorm ; outFlag = true ; end
                    if corr_dU<minCorrdU ; outFlag = true ; end
                    %if RMSE<1e-6 || abs((RMSE-RMSE_0)/RMSE) < 1e-4 ; outFlag = true ; end
                % Keep the error
                    %RMSE_0 = RMSE ;
            % POINTS/ELEMENTS VALIDATION/DELETION
                % DECORRELATED ELEMENTS
                    cullGeo = corrCoeff<minCorrCoeff | meanSquaredElemResid>maxMeanElemResidue ;
                    if any(cullGeo) && (outFlag || (normA/minNorm)<thresholdValidGeometry)
                        switch size(WEIGHT,2) 
                            case nElems % Correlation at the element level
                                VALID.Elems(VALID.Elems(:,ii),ii) = VALID.Elems(VALID.Elems(:,ii),ii) & ~cullGeo ; 
                            case nNodes % Correlation at the node level$
                                VALID.Nodes(VALID.Nodes(:,ii),ii) = VALID.Nodes(VALID.Nodes(:,ii),ii) & cullGeo ;
                        end
                        outFlag = false ; % Force an new iteration
                    end
                % SET THE NON-VALID NODES TO NAN
                    Xn(~VALID.Nodes(:,ii),:,ii) = NaN ;
                    Un(~VALID.Nodes(:,ii),:,ii) = NaN ;
            % DISPLAY
                % Always display infos
                    infosText.String = [ ' INFOS' ...
                                         ' | Frame: ' num2str(frames(ii)) ...
                                         ' | It: ' num2str(it) ...
                                         ' | norm.A: ' num2str(normA,2) ...
                                         ' | corr.dU: ' num2str(corr_dU,3) ...
                                         ] ; 
                % Heavy Plots
                    if plotEachIteration || (outFlag && plotEachFrame) || toc(lastPlotTime)>1/plotRate % (outFlag && toc(lastPlotTime)>1/plotRate)
                        im.CData = repmat(img2,[1 1 3]) ;
                        %%
                        residues = ... WEIGHT*corrCoeff ... Correlation coeffient
                                    abs(diffImg) ... NR residues
                                   ... WEIGHT*meanSquaredElemResid ... Sum of squared NR residues
                                   ... WEIGHT*((WEIGHT'*abs(diffImg))./sumWEIGHT) ...
                                   ;
                        imRes.CData(indDOMAIN) = residues ;
                        %%
                        mesh.Vertices = Xn(:,:,ii) ;
                        mesh.Faces = Elems(VALID.Elems(:,ii),:) ;
                        mesh.FaceVertexCData = ones(nNodes,1)*NaN ; mesh.FaceVertexCData(VALID.Nodes(:,ii)) = sqrt(sum(dU.^2,2)) ;
                        %figure(figDebug) ; clf ; ind = (0:nJ-1)*nI+ceil(nI/2) ; plot(img1v(ind)) ; plot(img2v(ind)) ;
                        lastPlotTime = tic ; 
                    end
            % Pause execution ?
                if pauseAtPlot && ~continueBtn.Value
                    while ~stopBtn.Value && ~nextBtn.Value && ~continueBtn.Value
                        drawnow ;
                    end
                    nextBtn.Value = 0 ;
                    if continueBtn.Value
                        nextBtn.Visible = 'off' ;
                        continueBtn.Visible = 'off' ;
                    end
                end
            % Draw
                drawnow ;
        end
        % Modify the reference image if needed
            if weightCurrentImage>0
                img1(indDOMAIN) = img1(indDOMAIN)*(1-weightCurrentImage) + img2v*weightCurrentImage ;
                refImageChanged = true ;
            end
        % Out Criterions
            if stopBtn.Value; break ; end
            if nVALID==0; break ; end
end