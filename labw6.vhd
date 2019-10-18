LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
USE ieee.numeric_std.ALL;
------------------library end-----------------------
ENTITY labw6 IS
	PORT (
		CLOCK_50 : IN std_logic; --CLK signal, KEY(0) for start the commnication
		KEY : IN std_logic_vector(3 DOWNTO 0);
		GPIO_0 : INOUT std_logic_vector(32 DOWNTO 0); --output signal GPIO(0) and GPIO(1)
		state_vector : OUT std_logic_vector(7 DOWNTO 0)
	);
END ENTITY;
------------------entity end------------------------
ARCHITECTURE behavior OF labw6 IS
	TYPE I2C_state IS (logic_1, logic_0, Idle, start_state_0, start_state_1, end_state_0, end_state_1, end_state_2, wait_key, clk_H_0, clk_H_1, clk_H_2, clk_L_0, clk_L_1, clk_L_2, slave_state, slave_state_1);
	SIGNAL Number, Number_next : INTEGER RANGE - 1 TO 15; -- counter signals, as a pointer
	SIGNAL data_sig, clock_sig, clk_line, dat_line : std_logic; -- “_sig” for signals that needs to be sent, “line” for signals that read from GPIO_0.
	SIGNAL slave_sig, old_key, old_key_next : std_logic; --slave_sig for the slave signal that received, old_key for the previous key press
	SIGNAL data_sig_data : std_logic_vector(15 DOWNTO 0); --the 16 bit data that sent
	SIGNAL state, next_state : I2C_state;
BEGIN
	------------translate the signal to real line signal------
	GPIO_0(0) <= '0' WHEN clock_sig = '0' ELSE 'Z'; --output the clk signal to signal line
	GPIO_0(1) <= '0' WHEN data_sig = '0' ELSE 'Z'; --output the data signal to data line
	data_sig_data <= "1010110011110001"; -- the data needs to be send
	--old_key_next <= KEY(2);
	GPIO_0(2) <= old_key;
	GPIO_0(3) <= old_key_next;
	------------------signal declarations end-----------
	PROCESS (next_state, data_sig, clock_sig, Number_next) -- state and inputs
	BEGIN
		------------------INITIAL CONDITION-----------------------------
		Number_next <= Number;
		next_state <= Idle;
		slave_sig <= '0';
		clock_sig <= '1';--;clk_line;
		data_sig <= '1';--dat_line;
		----------------The FSM part start ---------------
		CASE state IS --start the FSM
			WHEN Idle => -- the initial state
				Number_next <= 15;
				clock_sig <= '1';
				data_sig <= '1';
				IF clk_line = '1' AND dat_line = '1' THEN
					IF old_key_next = '0' AND old_key = '1' THEN --when key 0 pressed, start the communication
						next_state <= start_state_0; 
					ELSE
						next_state <= Idle;
					END IF;
				ELSE
					next_state <= Idle;
				END IF;
				---------------------------------------------START SIGNAL-----------------------------
			WHEN start_state_0 => -- to send the start signals to slaves #NO.1#
				data_sig <= '0'; --bring the data signal to 0 while clock is high to start the communication
				clock_sig <= '1';
				IF dat_line = '0' AND clk_line <= '1' THEN
					next_state <= start_state_1; --go to the next step of start
				ELSE
					next_state <= start_state_0;
				END IF;
			WHEN start_state_1 => -- #NO.2#
				clock_sig <= '0'; --bring the clock signal down to complet the start sequence
				data_sig <= '0';
				IF clk_line = '0' THEN
					next_state <= clk_L_0; --go to clock low state to start sending wave.
				ELSE
					next_state <= start_state_1;
				END IF;
				---------------------------------------------LOGIC SIGNAL-----------------------------
			WHEN logic_1 => -- the state to output a high voltage
				data_sig <= '1';
				clock_sig <= '0';
				IF dat_line = '1' THEN
					next_state <= clk_H_0;
				ELSE
					next_state <= logic_1;
				END IF;
			WHEN logic_0 => -- the state to ouput a low voltage
				data_sig <= '0';
				clock_sig <= '0';
				IF dat_line = '0' THEN
					next_state <= clk_H_0;
				ELSE
					next_state <= logic_0;
				END IF;
				---------------------------------------------CLOCK SIGNAL-----------------------------
			WHEN clk_L_0 => -- #NO.3#
				clock_sig <= '0'; --set
				data_sig <= dat_line;
				IF clk_line = '0' THEN
					IF data_sig_data(Number) = '1' THEN
						next_state <= logic_1; 
					ELSIF data_sig_data(Number) = '0' THEN
						next_state <= logic_0;
					END IF;
					Number_next <= Number - 1;
				ELSE
					next_state <= clk_L_0;
				END IF;
			WHEN clk_H_0 => 
				data_sig <= dat_line;
				clock_sig <= '1'; 
				IF clk_line = '1' THEN
					IF Number = 7 THEN
						next_state <= clk_L_1;
					ELSIF Number =- 1 THEN
						next_state <= clk_L_1; 
					ELSE
						next_state <= clk_L_0;
					END IF;
				ELSE
					next_state <= clk_H_0;
				END IF;
			WHEN clk_L_1 => --state to transfer to slave ACK/NACK
				clock_sig <= '0';
				data_sig <= dat_line;
				IF clk_line = '0' THEN
					IF Number = 7 THEN
						next_state <= slave_state; 
					ELSIF Number =- 1 THEN 
						next_state <= slave_state_1;
					END IF;
				ELSE
					next_state <= clk_L_1;
				END IF;
			WHEN slave_state => --state to read slave ACK/NACK(address)
				IF slave_sig = '1' THEN --if the slave not received signal
					data_sig <= '1';
					clock_sig <= clk_line;
					IF dat_line = '1' THEN
						next_state <= clk_H_1;
					ELSE
						next_state <= slave_state;
					END IF;
				ELSIF slave_sig = '0' THEN -- if the slave received signal
					data_sig <= '0';
					clock_sig <= clk_line;
					IF dat_line = '0' THEN
						next_state <= clk_H_1;
					ELSE
						next_state <= slave_state;
					END IF;
				END IF;
			WHEN slave_state_1 => --state to read slave ACK/NACK(Data)
				IF slave_sig = '1' THEN --if the slave not received signal
					data_sig <= '1';
					clock_sig <= clk_line;
					IF dat_line = '1' THEN
						next_state <= clk_H_2;
					ELSE
						next_state <= slave_state_1;
					END IF;
				ELSIF slave_sig = '0' THEN -- if the slave received signal
					data_sig <= '0';
					clock_sig <= clk_line;
					IF dat_line = '0' THEN
						next_state <= clk_H_2;
					ELSE
						next_state <= slave_state_1;
					END IF;
				END IF;
			WHEN clk_H_1 => --this state is use to read the slave return information
				clock_sig <= '1';
				data_sig <= dat_line;
				IF clk_line = '1' THEN
					IF dat_line = '1' THEN --high for NACK, no signal received
						next_state <= end_state_0; --end the signal 
					ELSIF dat_line = '0' THEN --low for ACK, signal received by slave.
						next_state <= clk_L_0; --start sending real information, 8-bit code. 
					END IF;
				ELSE
					next_state <= clk_H_1;
				END IF;
			WHEN clk_H_2 => -- this state is used to receive
				clock_sig <= '1';
				data_sig <= dat_line;
				IF clk_line = '1' THEN
					next_state <= clk_L_2; --end the signal 
				ELSE
					next_state <= clk_H_2;
				END IF;
			WHEN clk_L_2 => -- this state is used to end the data
				clock_sig <= '0';
				data_sig <= dat_line;
				IF clk_line = '0' THEN
					next_state <= end_state_0;
				ELSE
					next_state <= clk_L_2;
				END IF;
				---------------------------------------------END SIGNAL-------------------------------
			WHEN end_state_0 => -- to send the end signal to slaves #start ending#
				data_sig <= '0'; --bring the data line to low and clock high to start the ending
				clock_sig <= clk_line;
				IF dat_line = '0' AND clk_line = '0' THEN
					next_state <= end_state_1; --go to the second step for stop
				ELSE
					next_state <= end_state_0;
				END IF;
			WHEN end_state_1 => --second step to stop the communication
				clock_sig <= '1';
				data_sig <= dat_line;
				IF clk_line = '1' THEN
					next_state <= end_state_2; --end commnication finished, go to wait for user to release key
				ELSE
					next_state <= end_state_1;
				END IF;
			WHEN end_state_2 => --third step to stop the communication
				data_sig <= '1'; --last step to end #end ending#
				clock_sig <= '1';
				IF dat_line = '1' AND clk_line = '1' THEN
					next_state <= wait_key;
				ELSE
					next_state <= end_state_2;
				END IF;
				---------------------------------------------WAIT STATE-------------------------------
			WHEN wait_key => --wait the user to release the start key
				IF old_key_next = '1' AND old_key = '0' THEN
					next_state <= Idle; --when key released, back to initial state
				ELSE
					next_state <= wait_key;
				END IF;
		END CASE;
		-----------------End the FSM part-------------------
	END PROCESS;
	-----------------start the flip-flops---------------
	PROCESS (CLOCK_50, next_state, old_key, Data_sig, Number)
		BEGIN
			IF CLOCK_50'EVENT AND CLOCK_50 = '1' THEN
				IF key(0) = '1' THEN
					state <= next_state;
				ELSE
					state <= Idle;
				END IF;
				old_key_next <= KEY(2);
				old_key <= old_key_next;
				Number <= Number_next;
				clk_line <= GPIO_0(0);
				dat_line <= GPIO_0(1);
			END IF;
		END PROCESS;
		----------------End the flip-flop-------------------
END ARCHITECTURE;