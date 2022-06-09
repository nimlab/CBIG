function [lh_proj_data, rh_proj_data] = CBIG_RF_projectVol2fsaverage_single(input, interp, lh_map, rh_map, average)

% [lh_proj_data, rh_proj_data] = CBIG_RF_ProjectVol2fsaverage_single(input, interp, lh_map, rh_map, average)
%
% This function projects an input volume to fsaverage.
%
% Input:
%     - input :
%               input data in a volumetric atlas space
%               (assumed to have been read using MRIread)
%     - interp:
%               interpolation ('linear' or 'nearest')
%               (default: 'linear')
%     - lh_map:
%               absolute path to average mapping generated by RF approach for left hemisphere
%               the mapping file should contain a variable: ras
%               default is RF-ANTs MNI152-to-fsaverage mapping: 
%                 $CBIG_CODE_DIR/stable_projects/registration/Wu2017_RegistrationFusion/bin/
%                 final_warps_FS5.3/lh.avgMapping_allSub_RF_ANTs_MNI152_orig_to_fsaverage.mat
%               for RF-ANTs Colin27-to-fsaverage mapping use: 
%                 $CBIG_CODE_DIR/stable_projects/registration/Wu2017_RegistrationFusion/bin/
%                 final_warps_FS5.3/lh.avgMapping_allSub_RF_ANTs_Colin27_orig_to_fsaverage.mat
%               or for RF-M3Z mappings: change the 'RF_ANTs' in the file name to 'RF_M3Z'
%               Note that the folder name would be final_warps_FS4.5 if FreeSurfer 4.5 
%                 is currently in use. The same goes for other FreeSurfer versions
%     - rh_map:
%               absolute path to average mapping generated by RF approach for right hemisphere
%               the mapping file should contain a variable: ras
%               default is RF-ANTs MNI152-to-fsaverage mapping: 
%                 $CBIG_CODE_DIR/stable_projects/registration/Wu2017_RegistrationFusion/bin/
%                 final_warps_FS5.3/rh.avgMapping_allSub_RF_ANTs_MNI152_orig_to_fsaverage.mat
%               for RF-ANTs Colin27-to-fsaverage mapping use: 
%                 $CBIG_CODE_DIR/stable_projects/registration/Wu2017_RegistrationFusion/bin/
%                 final_warps_FS5.3/rh.avgMapping_allSub_RF_ANTs_Colin27_orig_to_fsaverage.mat
%               or for RF-M3Z mappings: change the 'RF_ANTs' in the file name to 'RF_M3Z'
%               Note that the folder name would be final_warps_FS4.5 if FreeSurfer 4.5 
%                 is currently in use. The same goes for other FreeSurfer versions
%     - average:
%               fsaverage mesh version ('fsaverage', 'fsaverage5', or 'fsaverage6')
%               (default: 'fsaverage')
%
% Output:
%     - lh_proj_data:
%                     projected results in left hemisphere 
%                     (1x163842 vector for fsaverage)
%     - rh_proj_data:
%                     projected results in right hemisphere 
%                     (1x163842 vector for fsaverage)
%
% Example:
% [lh_proj_data, rh_proj_data] = RF_CBIG_projectVol2fsaverage_single(input)
% This command reads in the input, using the default mapping as well as the default mask. 
% The input volume is projected to fsaverage surface using the mapping with linear interpolation.
%
% Written by Wu Jianxiao and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

%Function usage
if nargin < 1
    disp('usage: [lh_proj_data, rh_proj_data] = CBIG_RF_projectVol2fsaverage_single(input, interp, lh_map, rh_map, average)');
    return
end

%Add CBIG Matlab functions to path (added by William Drew in NIMLAB July 23, 2021)
addpath('/data/nimlab/software/CBIG/utilities/matlab/surf')
addpath('/data/nimlab/software/CBIG/external_packages/SD/SDv1.5.1-svn593/BasicTools')
addpath('/data/nimlab/software/CBIG/utilities/matlab/transforms')


%Get FreeSurfer version
fs_dir = getenv('FREESURFER_HOME');
addpath(fs_dir);
fs_stamp_file = fopen(fullfile(fs_dir, 'build-stamp.txt'), 'r');
fs_stamp = fgetl(fs_stamp_file);
stamp_start = regexp(fs_stamp, 'v\d.\d');
fs_ver = fs_stamp(stamp_start+1:stamp_start+3);
fclose(fs_stamp_file);

%Default parameters
dir_uti = fileparts(fileparts(mfilename('fullpath')));
if nargin < 2
    interp = 'linear';
end
if nargin < 3
    lh_map = fullfile(dir_uti, ['final_warps_FS' fs_ver], 'lh.avgMapping_allSub_RF_ANTs_MNI152_orig_to_fsaverage.mat');
end
if nargin < 4
    rh_map = fullfile(dir_uti, ['final_warps_FS' fs_ver], 'rh.avgMapping_allSub_RF_ANTs_MNI152_orig_to_fsaverage.mat');
end
if nargin < 5
    average = 'fsaverage';
end

%Set up index grid in the volumetric atlas space
[x1, x2, x3] = ndgrid(1:size(input.vol, 1), 1:size(input.vol, 2), 1:size(input.vol, 3));

%Loop through each hemisphere
data_dim = size(input.vol, 4);
for hemis = {'lh', 'rh'}
    hemi = hemis{1};
    
    %Get mapping to the corresponding hemisphere
    if(strcmp(hemi, 'lh'))
        load(lh_map);
    else
        load(rh_map);
    end
    
    %Set up parameters for fsaverage surface
    avg_mesh = CBIG_ReadNCAvgMesh(hemi, average, 'inflated', 'cortex');
    num_vertices = size(avg_mesh.vertices, 2);
    proj_data = zeros(data_dim, num_vertices);
    
    %Convert RAS correspondence to voxel coordinates and matrix coordinates
    vox_coor = CBIG_ConvertRas2Vox(ras(:, 1:num_vertices), input.vox2ras);
    mat_coor = [vox_coor(2, :)+1 ; vox_coor(1, :)+1; vox_coor(3, :)+1];
    
    %Project the input data to fsaverage
    for i = 1:data_dim
        proj_data(i, :) = interpn(x1, x2, x3, squeeze(input.vol(:, :, :, i)), mat_coor(1, :)', mat_coor(2, :)', mat_coor(3, :)', interp)';
    end
    
    %Assign output
    if(strcmp(hemi, 'lh'))
        lh_proj_data = proj_data;
    else
        rh_proj_data = proj_data;
    end
end

rmpath(fs_dir);
end
