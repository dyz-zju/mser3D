% Needs VL Feat library
% Uses code from frank01_mser

clear
clc
close all
run('../vlfeat-0.9.19/toolbox/vl_setup') % start up vl_feat
vl_version verbose
import gtsam.*

%% Tuning constants 
start = 1; %start at custom frame number. Default = 1.
stop = 30;  %end at custom frame number. Default = N.
threshold = -1; %Score threshold needed for two regions to be considered to come from the same object. A higher score indicates higher similarity.
memoryLoss = 6; %Higher memory loss throws away more of the old region knowledge with every frame. Increase memory loss when regions enter and exit the frame very quickly.
darknessFactor = 8; %When two regions are assigned the same color, we make the second region a sligtly darker hue. Decrease this to make subsequent regions darker.
MinDiversity = 0.7; %VL Feat tuning constant
MinArea = 0.005; %VL Feat tuning constant
MaxArea = 0.03; %VL Feat tuning constant
time1 = cputime;

%% Import video 
disp('Starting Video Import');
readerobj = VideoReader('../videos_input/through_the_cracks_jing.mov', 'tag', 'myreader1');
%readerobj = VideoReader('../videos_input/Walking_Video.MOV', 'tag', 'myreader1');
vidFrames = read(readerobj);
N = get(readerobj, 'NumberOfFrames');
disp('Video Import Finished');

%% Tuning constants 
start = 1; %start at custom frame number. Default = 1.
stop = N;  %end at custom frame number. Default = N.
threshold = -1; %Score threshold needed for two regions to be considered to come from the same object. A higher score indicates higher similarity.
memoryLoss = 6; %Higher memory loss throws away more of the old region knowledge with every frame. Increase memory loss when regions enter and exit the frame very quickly.
darknessFactor = 6; %When two regions are assigned the same color, we make the second region a sligtly darker hue. Decrease this to make subsequent regions darker.
MinDiversity = 0.7; %VL Feat tuning constant
MinArea = 0.005; %VL Feat tuning constant
MaxArea = 0.03; %VL Feat tuning constant

%% Set up video output
writer = VideoWriter('Nearest_Neighbor_Tracking_1','Uncompressed AVI'); %Uncompressed AVI required because mp4 doesnt work on Matlab for Linux :(
%writer.Quality = 100; %No quality parameter for uncompressed avi 
writer.FrameRate = 30;
open(writer);
frameTimes = zeros(N,1);
two_pane_fig = figure(1);
set(two_pane_fig, 'Position', [0,0,600,700]); 

%% Color choices
%                 red, orange, yellow, green, blue, purple, pink
brightRcolorset = [255, 255, 255,   0,   0, 127, 255];
brightGcolorset = [  0, 128, 255, 255, 128,   0,   0];
brightBcolorset = [  0,   0,   0,   0, 255, 255, 255]; 

%% Data structures
LastBrightEllipses = [0;0;0;0;0];
LastBrightColors = [1];

%% Process each video frame 
for f=start:stop
    %% Read image from video and resize + grayscale
    C = vidFrames(:,:,:,f);
    C = imresize(C,0.25);
    I=rgb2gray(C);    
    %Detect MSERs
    [Bright, BrightEllipses] = vl_mser(I,'MinDiversity',MinDiversity,'MinArea',MinArea,'MaxArea',MaxArea,'BrightOnDark',1,'DarkOnBright',0);
    %Compare new MSERs to previous MSERs
    brightScores = compareRegionEllipses(LastBrightEllipses,BrightEllipses);
    %Set up image data structures for output
    S = 128*ones(size(I,1),size(I,2),'uint8'); %grayscale result
    Q = 128*ones(size(I,1),size(I,2),3,'uint8'); %color result    
    currentBrightColors = ones(1,size(Bright,1));
    colorTable = zeros(1,7);
    %% Fill bright MSERs
    for i=size(Bright,1):-1:1
        mserS=vl_erfill(I,Bright(i));       
        %Convert region from grayscale to RGB
        [rS,cS] = ind2sub(size(S), mserS);
        mserC1 = sub2ind(size(C), rS, cS, 1*ones(length(rS),1));
        mserC2 = sub2ind(size(C), rS, cS, 2*ones(length(rS),1));
        mserC3 = sub2ind(size(C), rS, cS, 3*ones(length(rS),1));          
        %Check thershold
        if brightScores(2,i) > threshold
            colorIndex = LastBrightColors(brightScores(1,i));            
            %Assign slightly darker colors to associated regions. Use color
            %table to darken when a color is used more than once
            Q(mserC1) = brightRcolorset(colorIndex) / (1 + colorTable(colorIndex)/darknessFactor); 
            Q(mserC2) = brightGcolorset(colorIndex) / (1 + colorTable(colorIndex)/darknessFactor); 
            Q(mserC3) = brightBcolorset(colorIndex) / (1 + colorTable(colorIndex)/darknessFactor); 
        else
            colorIndex = randi([1,7],1,1);
        end
        colorTable(colorIndex) = colorTable(colorIndex) + 1;
        currentBrightColors(i) = colorIndex;                 
    end
    %Update data structures
    LastBrightEllipses = [BrightEllipses, LastBrightEllipses(:,1:cast(ceil(size(LastBrightEllipses,2))/memoryLoss,'uint8'))];
    LastBrightColors = [currentBrightColors, LastBrightColors(:,1:cast(ceil(size(LastBrightColors,2))/memoryLoss,'uint8'))];

    %% 2 quadrant video display
    %Quadrant 1: Original grayscale
    subplot(2,1,1);
    imshow(C); %original grayscale
    title('Original Video');
    set(gca,'FontSize',16,'fontWeight','bold')
    %Display frame number in a color appropriate to background brighness.
    if mean(C(30,20,:)) < 125 
        text(15,25,['#', num2str(f)],'FontSize',12,'fontWeight','bold','Color','w');
    else
        text(15,25,['#', num2str(f)],'FontSize',12,'fontWeight','bold','Color','k');
    end
    % Quadrant 2: MSER color
    subplot(2,1,2);
    imshow(Q)  
    title('Tracked MSER Regions');
    set(gca,'FontSize',16,'fontWeight','bold')    
    %Plot ellipses
    brightEllipsesTrans = vl_ertr(BrightEllipses);
    %vl_plotframe(brightEllipsesTrans, 'k-');
    %Produce and write video frame 
    frame = frame2im(getframe(two_pane_fig));
    writeVideo(writer,frame);
     
end
%% Time the process
close(writer);
time2 = cputime;
disp(['Elapsed time = ',num2str(time2 - time1)]);









