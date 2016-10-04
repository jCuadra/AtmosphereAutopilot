classdef aoa_controller < handle
    
    properties (SetAccess = public)
        model;                      % aircraft_model instance
        vel_c;                      % corresponding angular velocity controller
        axis = 0;                   % 0 - pitch 1 - roll 2 - yaw
        output_vel = 0.0;
        output_acc = 0.0;
        user_controlled = false;    % true when target is user control
        
        target_aoa = 0.0;
        cur_aoa_equilibr = 0.0;     % equilibrium angular velocity to stay on current AoA
        
        params = [1.0, 0.0, 0.0];        % math parameters
        
        already_preupdated = false;
    end
    
    methods (Access = public)
        function c = aoa_controller(axis, vc)
            c.vel_c = vc;
            c.model = vc.model;
            c.axis = axis;
        end
        
        function cntrl = eval(obj, target_aoa, target_vel, dt)
            obj.vel_c.preupdate();
            obj.update_pars(target_aoa);
            [obj.output_vel, obj.output_acc] = obj.get_desired_output(target_aoa, dt);
            cntrl = obj.vel_c.eval(obj.output_vel + target_vel, obj.output_acc, dt);
        end
        
        function preupdate(obj)
            obj.update_pars(0.0)
            obj.already_preupdated = true;
        end
    end
    
    methods (Access = private)
        
        function update_pars(obj, des_aoa)
            if (obj.already_preupdated)
                obj.already_preupdated = false;
                return
            end            
            cur_aoa = obj.model.aoa(obj.axis + 1);
            obj.cur_aoa_equilibr = obj.get_equlibr_v(cur_aoa);
        end
        
        function eq_v = get_equlibr_v(obj, aoa)
            if (obj.axis == 0)
                A = obj.model.pitch_A; 
                B = obj.model.pitch_B;
                C = obj.model.pitch_C;
            else
                A = obj.model.yaw_A; 
                B = obj.model.yaw_B;
                C = obj.model.yaw_C;
            end            
            
            eq_A = zeros(2);
            eq_B = zeros(2, 1);
            eq_A(1, 1) = A(1, 2);
            eq_A(1, 2) = A(1, 3) + A(1, 4) + B(1, 1);
            eq_A(2, 1) = A(2, 2);
            eq_A(2, 2) = A(2, 3) + B(2, 1) + A(2, 4);
            eq_B(1, 1) = -(A(1, 1) * aoa + C(1, 1));
            eq_B(2, 1) = -(A(2, 1) * aoa + C(2, 1));
            eq_x = eq_A \ eq_B;
            eq_v = eq_x(1, 1);
        end
        
        function des_v = get_des_v(obj, target_aoa_deriv, aoa)
            if (obj.axis == 0)
                A = obj.model.pitch_A; 
                B = obj.model.pitch_B;
                C = obj.model.pitch_C;
            else
                A = obj.model.yaw_A; 
                B = obj.model.yaw_B;
                C = obj.model.yaw_C;
            end
            
            des_v = (target_aoa_deriv - (aoa * A(1, 1) + ...
                     obj.model.csurf_state(obj.axis + 1) * (A(1, 3) + B(1, 1)) + ...
                     obj.model.gimbal_state(obj.axis + 1) * A(1, 4) + C(1, 1))) / A(1, 2);
        end
        
        function aoa_deriv = get_aoa_deriv(obj)
            if (obj.axis == 0)
                A = obj.model.pitch_A; 
                B = obj.model.pitch_B;
                C = obj.model.pitch_C;
            else
                A = obj.model.yaw_A; 
                B = obj.model.yaw_B;
                C = obj.model.yaw_C;
            end
            
            aoa_deriv = obj.model.aoa(obj.axis + 1) * A(1, 1) + ...
                     obj.model.csurf_state(obj.axis + 1) * (A(1, 3) + B(1, 1)) + ...
                     obj.model.gimbal_state(obj.axis + 1) * A(1, 4) + C(1, 1) + ...
                     obj.model.angular_vel(obj.axis + 1) * A(1, 2);
        end
        
        function [out_vel, out_acc] = get_desired_output(obj, target_aoa, dt)
            cur_aoa = obj.model.aoa(obj.axis + 1);
            obj.target_aoa = aircraft_model.clamp(target_aoa, obj.vel_c.res_min_aoa, obj.vel_c.res_max_aoa);
            
            error = target_aoa - cur_aoa;
            
            output = obj.get_output(error, dt);
            out_vel = obj.cur_aoa_equilibr + output; %obj.get_des_v(output);
            cur_ang_vel = obj.model.angular_vel(obj.axis + 1);
            shift_ang_vel = cur_ang_vel - obj.cur_aoa_equilibr;
            %if (shift_ang_vel * error > 0.0)
                predicted_aoa = cur_aoa + shift_ang_vel * dt;
                predicted_error = target_aoa - predicted_aoa;
                if (predicted_error * error < 0.0)
                    predicted_error = 0.0;
                    predicted_aoa = target_aoa;
                end
                predicted_eq_v = obj.get_equlibr_v(predicted_aoa);
                out_acc = (predicted_eq_v + obj.get_output(predicted_error, dt) - out_vel) / dt;
                %out_acc = 0.0;
            %else
            %    out_acc = 0.0;
            %end
        end
        
        function output = get_output(obj, error, dt)
            k = obj.params(1, 2) * obj.vel_c.kacc_quadr;
            x = -(abs(error) / k) ^ 0.33333;
            if (x >= - dt)
                output = error / dt;
            else
                output = sign(error) * k * ((x + dt) ^ 3.0 - (x + 0.0) ^ 3.0) / dt;
            end
        end
        
    end
    
end

