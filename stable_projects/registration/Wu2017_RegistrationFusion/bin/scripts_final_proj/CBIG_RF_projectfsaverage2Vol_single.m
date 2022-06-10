function [projected, projected_seg] = CBIG_RF_projectfsaverage2Vol_single(lh_input, rh_input, interp, map, mask_input)
% [lh_projected, rh_projected] = CBIG_RF_projectfsaverage2Vol_single(lh_input, rh_input, interp, map, mask_input)
%
% This function projects a pair of surface inputs (left and right hemispheres) 
% from fsaverage to a volume space (e.g, MNI152).
%
% Input:
%     - lh_input  :
%                   an 1xN array containing input in left hemisphere, 
%                     where N is the number of vertices
%     - rh_input  :
%                   an 1xN array containing  input in right hemisphere
%                     where N is the number of vertices
%     - interp    :
%                   interpolation ('linear' or 'nearest')
%                   (default: 'nearest')
%     - map       :
%                   absolute path to average mapping generated by Registration Fusion approach
%                   the mapping file should contain variables: lh_coord, rh_coord
%                   default is RF-ANTs fsaverage-to-MNI152 mapping: 
%                     $CBIG_CODE_DIR/stable_projects/registration/Wu2017_RegistrationFusion/bin/
%                     final_warps_FS5.3/allSub_fsaverage_to_FSL_MNI152_FS4.5.0_RF_ANTs_avgMapping.prop.mat
%                   for RF-ANTs fsaverage-to-Colin27 mapping use: 
%                     $CBIG_CODE_DIR/stable_projects/registration/Wu2017_RegistrationFusion/bin/
%                     final_warps_FS5.3/allSub_fsaverage_to_SPM_Colin27_FS4.5.0_RF_ANTs_avgMapping.prop.mat
%                   or for RF-M3Z mappings: change the 'RF_ANTs' in the file name to 'RF_M3Z'
%                   Note that the folder name would be final_warps_FS4.5 if FreeSurfer 4.5 
%                     is currently in use. The same goes for other FreeSurfer versions
%     - mask_input:
%                   absolute path to cortical mask. Dimensions of the mask volume also 
%                     determines the dimension of the output.
%                   note that this argument must be supplied if non-default map is used
%                   default is for MNI152: 
%                     $CBIG_CODE_DIR/stable_projects/registration/Wu2017_RegistrationFusion/bin/
%                     liberal_cortex_masks_FS5.3/FSL_MNI152_FS4.5.0_cortex_estimate.nii.gz
%                   for Colin27 use: 
%                     $CBIG_CODE_DIR/stable_projects/registration/Wu2017_RegistrationFusion/bin/
%                     liberal_cortex_masks_FS5.3/SPM_Colin27_FS4.5.0_cortex_estimate.nii.gz
%                   Note that the folder name would be liberal_cortex_masks_FS4.5 if FreeSurfer 4.5 
%                     is currently in use. The same goes for other FreeSurfer versions
%
% Output:
%     - projected    :
%                      projected results with left and right hemisphere combined 
%                      (same dimension as mask_input.vol)
%     - projected_seg:
%                      projected results in segmentation form, where right hemishpere values 
%                        start from 1000
%                      (same dimension as mask_input.vol)
%
% Example:
% [projected, projected_seg] = CBIG_RF_projectfsaverage2Vol_single(lh_labels, rh_labels, 'linear')
% This command reads in the two matrix 'lh_label' and 'rh_label', using the default mapping 
% as well as the default mask. The input matrix are projected to MNI space using the mapping 
% with nearest interpolation, with the same dimensions as the cortical mask.
%
% Written by Wu Jianxiao and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

if size(lh_input, 1) > 1
    error('Input argument ''lh_input'' should be a row vector');
end
if size(rh_input, 1) > 1
    error('Input argument ''rh_input'' should be a row vector');
end

%Function usage
if nargin < 2
    disp('usage: [lh_projected, rh_projected] = CBIG_RF_projectfsaverage2Vol_single(lh_input, rh_input, interp, map, mask)');
    return
end
if nargin < 5
    disp('custom mask must be supplied if non-default map is used.');
end

%Add CBIG Matlab functions to path (added by William Drew in NIMLAB July 23, 2021)
cbig_dir = getenv('NIMLAB_CBIG_PATH')
addpath(cbig_dir + "/utilities/matlab/surf")
addpath(cbig_dir + "/external_packages/SD/SDv1.5.1-svn593/BasicTools")
addpath(cbig_dir + "/utilities/matlab/transforms")
addpath(cbig_dir + "/external_packages/SD/SDv1.5.1-svn593/kd_tree")

%Get FreeSurfer version
fs_dir = getenv('FREESURFER_HOME');
addpath(fs_dir);
fs_stamp_file = fopen(fullfile(fs_dir, 'build-stamp.txt'), 'r');
fs_stamp = fgetl(fs_stamp_file);
stamp_start = regexp(fs_stamp, '\d\.\d');
fs_ver = fs_stamp(stamp_start:stamp_start+2);
fclose(fs_stamp_file);

%Default parameters
RH_SEG_START=1000; %For segmentation form, right hemisphere values start from 1000
dir_uti = fileparts(fileparts(mfilename('fullpath')));
if nargin < 3
    interp = 'nearest';
end
if nargin < 4
    map = fullfile(dir_uti, ['final_warps_FS' fs_ver], 'allSub_fsaverage_to_FSL_MNI152_FS4.5.0_RF_ANTs_avgMapping.prop.mat');
    mask_input = fullfile(dir_uti, ['liberal_cortex_masks_FS' fs_ver], 'FSL_MNI152_FS4.5.0_cortex_estimate.nii.gz');
end

%Load fsaverage spherical cortex mesh
lh_avg_mesh = CBIG_ReadNCAvgMesh('lh', 'fsaverage', 'sphere', 'cortex');
rh_avg_mesh = CBIG_ReadNCAvgMesh('rh', 'fsaverage', 'sphere', 'cortex');
if size(lh_input, 2) == 10242
    lh_orig_mesh = CBIG_ReadNCAvgMesh('lh', 'fsaverage5', 'sphere', 'cortex');
    rh_orig_mesh = CBIG_ReadNCAvgMesh('rh', 'fsaverage5', 'sphere', 'cortex');
elseif size(lh_input, 2) == 40962
    lh_orig_mesh = CBIG_ReadNCAvgMesh('lh', 'fsaverage6', 'sphere', 'cortex');
    rh_orig_mesh = CBIG_ReadNCAvgMesh('rh', 'fsaverage6', 'sphere', 'cortex');
elseif size(lh_input, 2) ~= 163842
    error('Invalid number of vertices.');
end

%Upsamle input data if they are in fsaverage5 or fsaverage6 sapce
if size(lh_input, 2) ~= 163842
    disp('Upsampling input data to fsaverage space...');
    lh_input = MARS_NNInterpolate_kdTree(lh_avg_mesh.vertices, lh_orig_mesh, lh_input);
    rh_input = MARS_NNInterpolate_kdTree(rh_avg_mesh.vertices, rh_orig_mesh, rh_input);
end

%Create binary mask for projection using input mappings
%Voxels with (0, 0, 0) mapping will be masked out
load(map);
lh_mask = double(sum(abs(lh_coord))~=0);
rh_mask = double(sum(abs(rh_coord))~=0);

%Project source surface to volume space by the chosen interpolation
switch interp
    case 'nearest'
        %Project lh
        lh_vertex = zeros(1, size(lh_coord, 2));
        lh_vertex(lh_mask~=0) = MARS_findNV_kdTree(single(lh_coord(:, lh_mask~=0)), lh_avg_mesh.vertices);
        lh_projected = zeros(1, size(lh_coord, 2));
        lh_projected(lh_mask~=0) = interpn(1:size(lh_input, 2), lh_input, lh_vertex(lh_mask~=0), 'nearest');
        
        %Project rh
        rh_vertex = zeros(1, size(rh_coord, 2));
        rh_vertex(rh_mask~=0) = MARS_findNV_kdTree(single(rh_coord(:, rh_mask~=0)), rh_avg_mesh.vertices);
        rh_projected = zeros(1, size(lh_coord, 2));
        rh_projected(rh_mask~=0) = interpn(1:size(rh_input, 2), rh_input, rh_vertex(rh_mask~=0), 'nearest');
        
    case 'linear'
        %Project lh
        lh_projected = zeros(1, size(lh_coord, 2));
        lh_projected(lh_mask~=0) = MARS_linearInterpolate_kdTree(single(lh_coord(:, lh_mask~=0)), lh_avg_mesh, single(lh_input));
        
        %Project rh
        rh_projected = zeros(1, size(rh_coord, 2));
        rh_projected(rh_mask~=0) = MARS_linearInterpolate_kdTree(single(rh_coord(:, rh_mask~=0)), rh_avg_mesh, single(rh_input));
    otherwise
        disp('Invalid interpolation option. Use either nearest or linear.');
end

%Mask out non-cortical areas using the mask provided
mask = MRIread(mask_input);
lh_error = sum(abs(double(lh_projected~=0) - mask.vol(:)'), 2);
rh_error = sum(abs(double(rh_projected~=0) - mask.vol(:)'), 2);
lh_projected(mask.vol(:)==0) = 0;
rh_projected(mask.vol(:)==0) = 0;
disp(['Total error for lh = ' num2str(lh_error) ', rh = ' num2str(rh_error)]);

%Combine results
projected = mask;
projected.vol = reshape(lh_projected + rh_projected, size(mask.vol));
rh_projected(rh_projected~=0) = rh_projected(rh_projected~=0) + RH_SEG_START;
projected_seg = mask;
projected_seg.vol = reshape(lh_projected + rh_projected, size(mask.vol));

rmpath(fs_dir);
end



