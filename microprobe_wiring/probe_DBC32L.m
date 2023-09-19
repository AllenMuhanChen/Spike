%plot probe_DBC32L
zpos= flipud([0:65:2015]');
ch_indices = [15, 16, 1, 30, 8, 23, 0, 31, 14, 17, 2, 29, 13, 18, 7, 24, 3, 28, 12, 19, 4, 27, 9, 22, 11, 20, 5, 26, 10, 21, 6, 25]';
probewiring = [ch_indices, repmat(0,32,1), repmat(0,32,1), zpos];
probewiring = sortrows(probewiring, 1, 'ascend');


s=[];
s.channels=probewiring(:,1);
s.x=probewiring(:,2);   %the reference electrode is always the top right channel when the probes are pointing up.
s.y=probewiring(:,3);
s.z=probewiring(:,4); 
s.z=s.z-min(s.z);
% s.shaft=probewiring(:,5);
% s.tipelectrode=tipelectrode;

% if strcmp(headstage_source,'Intan')
%     s.channels=s.channels-1;
% end

%To plot the labeled channels:
figure(2)
clf
plot(s.x,s.z,'sqr', 'MarkerSize',11)
hold on
for i=1:size(probewiring,1)
text(s.x(i)-5,s.z(i),num2str(s.channels(i)),'FontSize',9)
end
axis([min(s.x)-50 max(s.x)+50 min(s.z)-50 max(s.z)+50])
axis equal
set(gca,'FontSize',10,'TickDir','out')
