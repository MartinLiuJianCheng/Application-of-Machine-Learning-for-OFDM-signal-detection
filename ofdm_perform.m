clear all
clc
close all
%-------PARAMETER---------
N_train = 600001;
N_cv = 100001;
N_test = 100001;
Total_sample=64*N_cv;
N = 64; % Total number of sub-carriers per block
N_d = 52; % number of sub-carriers that holds data info per block
N_block = Total_sample/N; 
cp_length = ceil(0.25*N);
M = 4;  % PSK Mode
snr_db = 20;
snr = 10.^(snr_db/10);
sigma = sqrt(1./snr);
%-------------------------

%---Constellation Define--
for k=1:M 
    constellation(k,1) = cos((pi/M)+((2*pi*(k-1))/M))+(sin((pi/M)+((2*pi*(k-1))/M)))*sqrt(-1);
end
%-------------------------

%-----------64���� ������� �ٽ� ����-------(test)-------------------------
load ('test_input_channel_8_10db.mat','X_in','h')
load ('test_symbol_channel_8_10db.mat','m')
load ('test_output_predicted_channel_8_10dB.mat','predict')
% load ('test_output_expected_channel_8.mat','Y_out')
% 
% % load ('training_input_channel_4.mat','X_in','h')
% % load ('training_symbol_channel_4.mat','m')
% % load ('train_output_predicted_channel_4.mat','predict')
% % load ('training_output_expected_channel_4.mat','Y_out')
% 
% % load ('training_input.mat','X_in','h')
% % load ('training_symbol.mat','m')
% % load ('training_output_predicted.mat','predict')
% % load ('training_output_expected.mat','Y_out')
% 
% predict = (1/sqrt(N)).*predict;        % sqrt(N)���� ������ ������ ifft-fft Ư�� ���� 
% X_in = (1/sqrt(N)).*X_in;
% Y_out = (1/sqrt(N)).*Y_out;

% ------------------------------------
predict = (1/N).*predict;        % sqrt(N)���� ������ ������ ifft-fft Ư�� ���� -> N
X_in = (1/N).*X_in;
% Y_out = (1/N).*Y_out;

Y_test_out=zeros(N,N_block-1);
for k=1:N_block-1
    for j=1:cp_length 
        %Y_test_out(j,k)=Y_out(k,j)+(Y_out(k,cp_length+j))*1i;
        Y_test_out(j,k)=predict(k,j)+(predict(k,cp_length+j))*1i;
    end
    for l=cp_length+1:N
       Y_test_out(l,k)=X_in(k,2*(N-cp_length)+(l-cp_length))+X_in(k,3*(N-cp_length)+(l-cp_length))*1i; 
    end
end
% -----------------------------

%-----------64���� ������� �ٽ� ����-------(rx)-------------------------
% load('test_rx_cp_x_channel_8_35db.mat','rx_signal_cp_not_added','rx_signal_cp_added','h','m')
% 
% %cp ��� ���Ѱ� ���� ����
% Y_test_out=zeros(N,N_block-1);
% for k=1:N_block-1
%     Y_test_out(:,k) = rx_signal_cp_not_added(:,k+1); 
% end

%cp ����� �� ���� ����
% Y_test_out=zeros(N,N_block-1);
% for k=1:N_block-1
%     Y_test_out(:,k) = rx_signal_cp_added(1+cp_length:end,k+1);  %�տ� 16�� ������ �ڿ� 64�� �����ͼ� ����
% end
%-----------------------------------------------------------------

%------Detecting & Compensation-----------------------------------

% FFT'd symbols, fft�� ���� �ٽ� ����.
for j=1:N_block-1
    H=fft([h(:,j+1); zeros(N-cp_length,1)]);  % y=diag(H)'*F'*(rx.')
    Y_test_out_symbol(:,j)=inv(abs(diag(H)).^2)*diag(H)'*fft(Y_test_out(:,j));
end
%-----------------------------------------------------------------

for i=1:N_block-1 % exracting Tx symbol with 52 important sub-carriers
    Y_part_test_out_symbol(:,i) = [Y_test_out_symbol(N/2-N_d/2:N/2-1,i);Y_test_out_symbol(N/2+1:N/2+N_d/2,i)];
end

% save('Y_symbol_cp_o.mat','Y_part_test_out_symbol')
% save('Y_symbol_cp_x.mat','Y_part_test_out_symbol')
% save('Y_symbol_ANN.mat','Y_part_test_out_symbol')

for i=1:N_d % Boundary-Mapping, symbol�� 4���� boundary�� ������ �۾�
    for k=1:N_block-1
        if (real(Y_part_test_out_symbol(i,k))>0)&&(imag(Y_part_test_out_symbol(i,k))>0)
            Y_part_test_out_symbol_af(i,k) = constellation(1);
        elseif (real(Y_part_test_out_symbol(i,k))<0)&&(imag(Y_part_test_out_symbol(i,k))>0)
            Y_part_test_out_symbol_af(i,k) = constellation(2);
        elseif (real(Y_part_test_out_symbol(i,k))<0)&&(imag(Y_part_test_out_symbol(i,k))<0)
            Y_part_test_out_symbol_af(i,k) = constellation(3);
        else
            Y_part_test_out_symbol_af(i,k) = constellation(4);
        end
    end
end
for i=1:N_d % Differ-Calculation, ������ constellation�� ���Ѵ�.
    for k=1:N_block-1
%         if m(i,k+1)==Y_part_test_out_symbol_af(i,k)
        if abs(m(i,k+1)-Y_part_test_out_symbol_af(i,k)) < 0.00001
            A_NN(i,k) = 0;
        else 
            A_NN(i,k) = 1;
        end
    end
end

% BER-Calculation
for j=1:N_block-1
    S(j) = sum(A_NN(:,j));
end
SER= sum(S)/(N_d*(N_block-1));