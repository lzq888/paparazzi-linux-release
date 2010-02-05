clear();
clearglobal();


exec('q3d_utils.sci');
exec('q3d_fdm.sci');
exec('q3d_ctl.sci');
exec('q3d_ref_misc.sci');



l_t0 = 0;
l_duration = 2.2;
l_center = [0;0];
l_radius = 1;
[time, Xref] = get_reference_looping(l_t0, l_duration, l_center, l_radius);


fdm_init(0,time($));

ctl_init();

global ctl_motor;
ctl_motor(:,1) = fdm_mass * fdm_g * [0.5;0.5];

global ctl_ref_0;
global ctl_ref_1;
global ctl_ref_2;
global ctl_ref_3;
global ctl_ref_4;
ctl_ref_0 =  Xref(1:2,:);
ctl_ref_1 =  Xref(3:4,:);
ctl_ref_2 =  Xref(5:6,:);
ctl_ref_3 =  Xref(7:8,:);
ctl_ref_4 =  Xref(9:10,:);

//global fdm_state;
fdm_state(FDM_SX, 1) = ctl_ref_0(AXIS_X,1);
fdm_state(FDM_SZ, 1) = ctl_ref_0(AXIS_Z,1);
fdm_state(FDM_SXD, 1) = ctl_ref_1(AXIS_X,1);
fdm_state(FDM_SZD, 1) = ctl_ref_1(AXIS_Z,1);
ctl_run_flatness(1);
//global ctl_ref_thetad;
fdm_state(FDM_STHETA, 1)  = ctl_ref_theta(1);
fdm_state(FDM_STHETAD, 1) = ctl_ref_thetad(1);

for i=1:length(fdm_time)-1

  fdm_run(i+1, ctl_motor(:,i));
  ctl_run_flatness(i+1);
  
end
if 1
clf();
plot2d(fdm_state(FDM_SX,:), fdm_state(FDM_SZ,:),2);
plot2d(ctl_ref_0(AXIS_X,:), ctl_ref_0(AXIS_Z,:),3);
  pause
end
clf();
drawlater();
ctl_display();
drawnow();
  pause

gen_video();