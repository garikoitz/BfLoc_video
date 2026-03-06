function k = get_keyboard_num
% Checks to make sure that the laptop keyboard is used in case another
% device connected at the scanner also has the usageName Keyboard
% (keyboardID should be set to the productID of the native keyboard).
% Written by KGS Lab
% Edited by AS 8/2014

% change to productID number of native keyboard
% Linux box productID 8467 12314
keyboard_id = 24729; k = 0; d = PsychHID('Devices');
for nn = 1:length(d)
    if (d(nn).productID == keyboard_id) % && strcmp(d(nn).usageName, 'Keyboard');
         k = nn;
         break
     end
 end
 if k == 0
     fprintf('\nKeyboard not found.\n');
 end
% k=1
disp('\n ####')
disp('\n The keybord device index is')
disp(k)

end
