%% Codice per la ricezione del segnale RDS dalla banda radio FM

%% INIZIALIZZAZIONE

userInput = helperRBDSInit();
userInput.Duration = 100; % tempo di cattura (secondi)
%userInput.SignalSource = 'File';
%userInput.SignalFilename = 'rbds_capture.bb';
userInput.SignalSource = 'RTL-SDR';
userInput.CenterFrequency = 102.5e6; %102.5, 103, 101.8, 104.5
userInput.RadioAddress = '0';

[rbdsParam, sigSrc] = helperRBDSConfig(userInput); % Configura i parametri per il RDS e specifica la struct della sorgente (RTLSDR nel nostro caso)

% Creazione oggetto che effettua la demodulazione della banda FM (per la riproduzione audio)
fmBroadcastDemod = comm.FMBroadcastDemodulator(...
    'SampleRate',228e3, ...
    'FrequencyDeviation',rbdsParam.FrequencyDeviation, ...
    'FilterTimeConstant',rbdsParam.FilterTimeConstant, ...
    'AudioSampleRate',rbdsParam.AudioSampleRate, ...
    'Stereo',true);

% Creazione oggetto audio player
player = audioDeviceWriter('SampleRate',rbdsParam.AudioSampleRate);

% Layer 2 object
datalinkDecoder = RBDSDataLinkDecoder();

% Layer 3 object
sessionDecoder  = RBDSSessionDecoder();

% % register processing implementation for RadioText Plus (RT+) ODA:
% rtID = '4BD7';
% registerODA(sessionDecoder, rtID, @RadioTextPlusMainGroup, @RadioTextPlus3A);

% Creazione del data viewer object (TABELLONA)
viewer = helperRBDSViewer();

% Visualizza il viewer ed inizializza radioTime
start(viewer)
radioTime = 0;


%% MAIN LOOP

while radioTime < rbdsParam.Duration
    % Ricevo i campioni dalla RTL-SDR (Signal Source a 228kHz)
    rcv = sigSrc();

    % Demodulazione FM e riproduzione dell'audio
    audioSig = fmBroadcastDemod(rcv);
    player(audioSig);

    % Physical layer processing (Layer 1)
    bitsPHY = RBDSPhyDecoder(rcv, rbdsParam, 1);

    % Data-link layer processing (Layer 2)
    [enabled,iw1,iw2,iw3,iw4] = datalinkDecoder(bitsPHY);

    % Session and presentation layer processing (Layer 3)
    outStruct = sessionDecoder(enabled,iw1,iw2,iw3,iw4);

    % Aggiorno il viewer per vedere i risultati
    update(viewer, outStruct);

    % Aggiorno radioTime con il tempo di processing di 1 frame
    radioTime = radioTime + rbdsParam.FrameDuration;
end


% Chiusura e rilascio dei moduli oggetto utilizzati
stop(viewer);
release(sigSrc);
release(player);