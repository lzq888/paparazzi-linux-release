//
// Flight Dynamic Model of a planar quadrotor
//

//
// State Vector
//
FDM_SX      = 1;
FDM_SZ      = 2;
FDM_STHETA  = 3;
FDM_SXD     = 4;
FDM_SZD     = 5;
FDM_STHETAD = 6;
FDM_SSIZE   = 6;

//
// Actuators
//
FDM_MOTOR_RIGHT = 1;
FDM_MOTOR_LEFT  = 2;
FDM_MOTOR_NB    = 2;

fdm_g       = 9.81;
fdm_mass    = 0.25;
fdm_inertia = 0.0078;

fdm_min_thrust =  0.5 * 0.1 * fdm_mass * fdm_g;
fdm_max_thrust =  0.5 * 4.0 * fdm_mass * fdm_g;

fdm_dt = 1./512.;

global fdm_time;
global fdm_state;
global fdm_accel;


function fdm_init(time_ref, ref) 

  global fdm_time;
  fdm_time = time_ref;
  global fdm_state;
  fdm_state = zeros(FDM_SSIZE, length(fdm_time));
  fdm_state(:,1) = ctl_state_of_flat_out(ref);
  
endfunction

function fdm_run(i, cmd)
 
  cmd = trim_vect(cmd, fdm_min_thrust, fdm_max_thrust);
  global fdm_state;
  global fdm_time;
  fdm_state(:,i) = ode(fdm_state(:,i-1), fdm_time(i-1), fdm_time(i), list(fdm_get_derivatives, cmd));
  
endfunction

function [Xdot] = fdm_get_derivatives(t, X, U)

  Xdot = zeros(length(X),1);
  Xdot(FDM_SX) = X(FDM_SXD);
  Xdot(FDM_SZ) = X(FDM_SZD);
  Xdot(FDM_STHETA) = X(FDM_STHETAD);
  Xdot(FDM_SXD) = -sum(U)/fdm_mass*sin(X(FDM_STHETA));
  Xdot(FDM_SZD) = 1/fdm_mass*(sum(U)*cos(X(FDM_STHETA))-fdm_mass*fdm_g);
  Xdot(FDM_STHETAD) = 1/fdm_inertia*(U(FDM_MOTOR_RIGHT) - U(FDM_MOTOR_LEFT));
  
  
endfunction

