clear;
model = aircraft_model();
model.aero_model = false;         % stock model
model.force_spd_maintain = true;
pitch_acc_c = ang_acc_pitch_yaw(0, model);
pitch_vel_c = ang_vel_pitch_yaw(0, pitch_acc_c);
pitch_aoa_c = aoa_controller(0, pitch_vel_c);
pitch_aoa_c.params = [3.0, 0.08, 500.0];
dt = 0.05;
sim_length = 80;
time = zeros(1, sim_length);
positions = zeros(3, sim_length);
forwards = zeros(3, sim_length);
rights = zeros(3, sim_length);
aoas = zeros(3, sim_length);
speed = zeros(1, sim_length);
ang_acc = zeros(3, sim_length);
ang_vel = zeros(3, sim_length);
output_vel = zeros(1, sim_length);
output_acc = zeros(1, sim_length);
real_setpoint_acc = zeros(1, sim_length);
cntrl = zeros(3, sim_length);
csurf = zeros(3, sim_length);

frame = 1;
positions(:, frame) = model.position.';
forwards(:, frame) = model.forward_vector.';
rights(:, frame) = model.right_vector.';
aoas(:, frame) = model.aoa.';
speed(frame) = model.velocity_magn;
csurf(:, frame) = model.csurf_state;
ang_acc(:, frame) = model.angular_acc;
ang_vel(:, frame) = model.angular_vel;

for frame = 2:sim_length
    time(frame) = dt * (frame - 1);
    model.preupdate(dt);
    if (time(frame) > 0.0 && time(frame) < 2.0)
        des_aoa = 0.2;
    else
        des_aoa = 0.0;
    end
    p_output = pitch_aoa_c.eval(des_aoa, 0.0, dt);
    output_vel(frame) = pitch_aoa_c.output_vel;
    output_acc(frame) = pitch_aoa_c.output_acc;
    real_setpoint_acc(frame) = (output_vel(frame) - output_vel(frame-1)) / dt;
    cntrl(:, frame) = [p_output, 0, 0];
    %cntrl(:, frame) = [0, r_output, 0];
    model.simulation_step(dt, cntrl(:, frame));
    
    positions(:, frame) = model.position.';
    forwards(:, frame) = model.forward_vector.';
    rights(:, frame) = model.right_vector.';
    aoas(:, frame) = model.aoa.';
    speed(frame) = model.velocity_magn;
    csurf(:, frame) = model.csurf_state;
    ang_acc(:, frame) = model.angular_acc;
    ang_vel(:, frame) = model.angular_vel;
end
%% Plot pitch parameters
h = figure(1338);
hold on
H0 = plot(time, ang_acc(1,:), 'b');
[AX, H1, H2] = plotyy(time, ang_vel(1,:), time, aoas(1, :));
set(H1, 'Color', 'g');
set(H2, 'Color', 'm');
H3 = plot(time, cntrl(1,:), 'r');
H4 = plot(time, csurf(1,:), 'k:');
H5 = plot(time, output_vel, 'g:');
H6 = plot(time, real_setpoint_acc, 'k');
H7 = plot(time, output_acc, 'k--');
hold off
xlabel('time');
legend([H0,H1,H2,H3,H4,H5,H6,H7], 'acc', 'ang vel', 'AoA', 'pitch ctrl', 'pitch csurf', 'output vel',...
    'true setpoint deriv', 'output acc');
h = gca;
set(h, 'Position', [0.045 0.08 0.91 0.90]);