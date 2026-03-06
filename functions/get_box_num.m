%Use this for the Button box ID in the MRI room

function b = get_box_num
% Checks connected USB devices and returns the device number corresponding
% to the scanner button box (box_id should be set to the productID of
% the button box used locally).
% Written by KGS Lab
% Edited by AS 8/2014

% Set the productID of your button box (update if it ever changes)
box_id = 12314;

% Initialize output
b = 0;

% Get list of all connected input devices
d = PsychHID('Devices');

% Loop through all devices to find a match
for nn = 1:length(d)
    if d(nn).productID == box_id
        b = nn;
        break;  % Stop as soon as found
    end
end

% Warn user if box not found
if b == 0
    fprintf('\nButton box not found.\n');
else
    fprintf('\nButton box found at device number: %d\n', b);
end

end











%Use this upstair for the get_box_num
%{
function b = get_box_num
% Checks connected USB devices and returns the device number corresponding
% to the scanner button box (box_id should be set the the productID of
% the button box used locally).
% Written by KGS Lab
% Edited by AS 8/2014

% change to productID number of local button box
box_id = 8467; b = 0; d = PsychHID('Devices');
for nn = 1:length(d)
    if (d(nn).productID == box_id) && (strcmp(d(nn).usageName, 'Keyboard'))
        b = nn;
    end
end
if b == 0
    fprintf('\nButton box not found.\n');
end
%b = 2
end


%this is to access the number of USB connected
%{
devices = PsychHID('Devices');

for i = 1:length(devices)
    fprintf('\nDevice %d:\n', i);
    fprintf('  Product Name : %s\n', devices(i).product);
    fprintf('  Usage Name   : %s\n', devices(i).usageName);
    fprintf('  Vendor ID    : %d\n', devices(i).vendorID);
    fprintf('  Product ID   : %d\n', devices(i).productID);
    fprintf('  Manufacturer : %s\n', devices(i).manufacturer);
    fprintf('  Serial Number: %s\n', devices(i).serialNumber);
end

%}

%}














