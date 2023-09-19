%generate wiring information for single electrode
%standard format for columns in probewiring:
%column 1: channel number (starts with 0)
%column 2: x
%column 3: y
%column 4: z
%column 5: shaft
function probewiring=probeConfig_DBC32L
zpos= flipud([0:65:2015]');
ch_indices = [15, 16, 1, 30, 8, 23, 0, 31, 14, 17, 2, 29, 13, 18, 7, 24, 3, 28, 12, 19, 4, 27, 9, 22, 11, 20, 5, 26, 10, 21, 6, 25]';
probewiring = [ch_indices, repmat(0,32,1), repmat(0,32,1), zpos, repmat(1,32,1)];
probewiring = sortrows(probewiring, 1, 'ascend');
% probewiring=[
%     0	0	0	1025	1
% 1	0	0	925	1
% 2	0	0	825	1
% 3	0	0	725	1
% 4	0	0	625	1
% 5	0	0	525	1
% 6	0	0	425	1
% 7	0	0	325	1
% 8	0	0	225	1
% 9	0	0	125	1
% 10	0	0	25	1
% 11	0	0	50	1
% 12	0	0	100	1
% 13	0	0	150	1
% 14	0	0	200	1
% 15	0	0	250	1
% 16	0	0	1050	1
% 17	0	0	1000	1
% 18	0	0	950	1
% 19	0	0	900	1
% 20	0	0	850	1
% 21	0	0	800	1
% 22	0	0	750	1
% 23	0	0	700	1
% 24	0	0	650	1
% 25	0	0	2000	1
% 26	0	0	550	1
% 27	0	0	500	1
% 28	0	0	450	1
% 29	0	0	400	1
% 30	0	0	350	1
% 31	0	0	300	1
% ];