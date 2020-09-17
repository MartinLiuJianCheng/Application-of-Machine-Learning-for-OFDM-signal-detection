clear all
clc
close all
%-------PARAMETER---------
N_train = 600001;
N_cv = 100001;
N_test = 100001;
Total_sample=64*N_cv;
N = 64; % Total number of sub-carriers per block
N_d = 52; % number of sub-carriers that holds data info per block, �����Ͱ� ���� ���� 52��, �������� 0���� ó��.
N_block = Total_sample/N;
cp_length = ceil(0.25*N); % cp_length�� 1/4, 16���� ����
M = 4;  % PSK Mode, QPSK, 4��
%-------------------------

%---Constellation Define--
for k=1:M 
    constellation(k,1) = cos((pi/M)+((2*pi*(k-1))/M))+(sin((pi/M)+((2*pi*(k-1))/M)))*sqrt(-1);  % QPSK, 4����
end
%-------------------------

%---Channel Power Delay Profile---
pdp=zeros(cp_length,1);
for i=1:cp_length
     if (i>=1&&i<=8)
         pdp(i,1)=exp(-(i-1)/4);     % channel pdp�� expotenial, �����Լ��� ���� 1~8�� ����
     end
end
pdp=pdp/sum(pdp);
%---------------------------------

%----------SNR setting-------------
snr_db=10;                              % SNR�� 10dB ~ 35dB�� 5dB�� �÷����� ������ ��
snr=10.^(snr_db/10);
sigma=sqrt(1./snr);
%----------------------------------

%-------------------------------TRANSMITTER--------------------------------
for k=1:N_d                            % Data symbol generation
    for i=1:N_block
        t=ceil(M*rand(1,1));           % �����ϰ� ���� �����
        m(k,i)=constellation(t);       % 52���� �ڸ��� ����
    end
end

for k=1:N_block % OFDM symbol generation using IFFT
    x(:,k)=[zeros(N/2-N_d/2-1,1); m(1:N_d/2,k); 0; m(N_d/2+1:N_d,k); zeros(N/2-N_d/2,1)];   % 52�� ������ �ְ�, �������� 0 ����!
                                                                                            % �Ǿ� ���� 5��, �߰� 1��, �� �� 6�� 0����.
    tx_symbol_without_cp(:,k)=ifft(x(:,k));         % ifft�� ���� 
    tx_symbol_with_cp(:,k)= [tx_symbol_without_cp(N-cp_length+1:N,k);tx_symbol_without_cp(:,k)];
    
    for i=1:cp_length
        h(i,k)=sqrt(pdp(i))*(randn+sqrt(-1)*randn);     % ä�� Ư�� ����
    end
end
%--------------------------------------------------------------------------

for k=1:N_block-1   % �پ��ִ� symbol 2������ ��� tx_pair�� ����
    tx_pair(:,k) =  [tx_symbol_without_cp(:,k) ; tx_symbol_without_cp(:,k+1)];   
end

%-----------------------------------receiver-------------------------------------------------------------------------------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%-----------------------------------Rx No cp ------------------------------

rx_signal_cp_not_added=zeros(N,N_block); % �ϴ� ��ü 0���� ����
for i=1:cp_length % received signal
    for k=1:N_block
        if k==1     % ó�� ������ ��ȣ, ù��° symbol�� ���� tx ��ȣ�� ����, ä��Ư���� �߰��� ����.
            rx_signal_cp_not_added(:,k)=rx_signal_cp_not_added(:,k)+h(i,k)*[zeros(i-1,1); tx_symbol_without_cp(1:(N-i+1),k)];      
        else
            if i==1     %���� symbol�� ���, ó�� ����
                rx_signal_cp_not_added(:,k)=rx_signal_cp_not_added(:,k)+h(i,k)*tx_symbol_without_cp(:,k);
            else    % �з��� ���´� ��ȣ.
                rx_signal_cp_not_added(:,k)=rx_signal_cp_not_added(:,k)+[h(i,k-1)*tx_symbol_without_cp(N-i+2:N,k-1);h(i,k)*tx_symbol_without_cp(1:(N-i+1),k)];
            end
        end
    end
end

%----------------------------------- Rx Yes cp ---------------------------

rx_signal_cp_added=zeros(N+cp_length,N_block); % �ϴ� ��ü 0���� ����
for i=1:cp_length % received signal
    for k=1:N_block
        if k==1     % ó�� ������ ��ȣ, ù��° symbol�� ���� tx ��ȣ�� ����, ä��Ư���� �߰��� ����.
            rx_signal_cp_added(:,k)=rx_signal_cp_added(:,k)+h(i,k)*[zeros(i-1,1); tx_symbol_with_cp(1:(N-i+1+cp_length),k)];      
        else
            if i==1     %���� symbol�� ���, ó�� ����
                rx_signal_cp_added(:,k)=rx_signal_cp_added(:,k)+h(i,k)*tx_symbol_with_cp(:,k);
            else    % �з��� ���´� ��ȣ.
                rx_signal_cp_added(:,k)=rx_signal_cp_added(:,k)+[h(i,k-1)*tx_symbol_with_cp(N-i+2+cp_length:N+cp_length,k-1);h(i,k)*tx_symbol_with_cp(1:(N-i+1+cp_length),k)];
            end
        end
    end
end

%----------------------------------------------------------------------------------------------------------------------------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%������� Received Signal%%%%%%%%%%%%%%%%%%%%%
%RX�� Noise �߰�
for k=1:N_block
    AWGN_cp_x = sigma*(randn(N,1)+sqrt(-1)*randn(N,1))/(N*sqrt(2));    % AWGN, ������  (N*sqrt(2)) ���� sqrt(2)�� �ٲ�
    rx_signal_cp_not_added(:,k) = rx_signal_cp_not_added(:,k) + AWGN_cp_x;   % cp�� �������� ���� rx ��ȣ�� AWGN ��ȣ �߰�.
    
    AWGN_cp_o = sigma*(randn(N+cp_length,1)+sqrt(-1)*randn(N+cp_length,1))/(N*sqrt(2));    % AWGN, ������
    rx_signal_cp_added(:,k) = rx_signal_cp_added(:,k) + AWGN_cp_o;   % cp�� �������� ���� rx ��ȣ�� AWGN ��ȣ �߰�.
end

%------- Data reshaping for Neural Network---------------------------------
X_material = zeros(2*(N-cp_length),N_block-1);              % reshape �� �� 48*2, ���� symbol���� ��ġ�� �κ� �����ϰ�,
Y_material = zeros(cp_length,N_block-1);                    % (16 x N_block-1), isi!

        % tx pair�� �̿��� X_material, Y_material ����
for k=1:N_block-1
    AWGN_NN = sigma*(randn(2*N-cp_length,1)+sqrt(-1)*randn(2*N-cp_length,1))/(N*sqrt(2));    % AWGN ����
    for i=1:cp_length
        X_material(:,k)=X_material(:,k) + h(i,k+1)*[tx_pair(cp_length+2-i:N+1-i,k);tx_pair(N+cp_length+2-i:N+N+1-i,k)];
        if i==1
            Y_material(:,k)=Y_material(:,k) + h(i,k+1)*[tx_pair(N+1:N+cp_length+1-i,k)];
        else 
            Y_material(:,k)=Y_material(:,k) + h(i,k+1)*[tx_pair(N+N-i+2:N+N,k);tx_pair(N+1:N+cp_length+1-i,k)];
        end
    end
            % AWGN �߰�
    X_material(:,k)=X_material(:,k)+AWGN_NN(1:2*(N-cp_length),1);
    Y_material(:,k)=Y_material(:,k)+AWGN_NN(2*(N-cp_length)+1:end,1);
end    
        
        
X_in = zeros(N_block-1,4*(N-cp_length)+2*cp_length);
for i=1:(N_block-1)
    for j=1:(N-cp_length)
        X_in(i,j) = real(X_material(j,i));
    end
    for k=1:(N-cp_length)
        X_in(i,(N-cp_length)+k) = imag(X_material(k,i));
    end
    for s=1:(N-cp_length)
        X_in(i,2*(N-cp_length)+s) = real(X_material(s+(N-cp_length),i));
    end
    for t=1:(N-cp_length)
        X_in(i,3*(N-cp_length)+t) = imag(X_material(t+(N-cp_length),i));
    end
    for p=1:cp_length
        X_in(i,4*(N-cp_length)+p) = real(h(p,i+1));
    end
    for q=1:cp_length
        X_in(i,4*(N-cp_length)+cp_length+q) = imag(h(q,i+1));
    end
end

Y_out = zeros(N_block-1,2*(cp_length));
for k=1:N_block-1
    for i=1:cp_length
        Y_out(k,i)= real(Y_material(i,k));
    end
    for j=1:cp_length
        Y_out(k,j+cp_length)=imag(Y_material(j,k));
    end 
end
X_in = N.*X_in;
Y_out = N.*Y_out;


% save('training_input_channel_8.mat','X_in','h')
% save('training_output_expected_channel_8.mat','Y_out')
% save('training_symbol_channel_8.mat','m')

% save('cv_input_channel_8.mat','X_in','h')
% save('cv_output_channel_8.mat','Y_out')

%%% �̸� 16 ä�η� �ٲ���� %%%
save('test_input_channel_8_10db.mat','X_in','h')
% save('test_output_expected_channel_8.mat','Y_out')
save('test_symbol_channel_8_10db.mat','m')
% save('test_rx_cp_x_channel_8_35dB.mat','rx_signal_cp_not_added','rx_signal_cp_added','h','m')