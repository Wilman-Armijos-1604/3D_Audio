function [audioProcesado, Fs] = generarAudioVariable(elev, limitesAzim, intervalos, archivoAudio, banderaCrear)
    %% Lectura de la señal
    [audio, Fs]=audioread(archivoAudio);
    
    %% Variables para la ejecución
    dist=abs(limitesAzim(1)-limitesAzim(2));
    distinters=dist/(intervalos);

    azims=zeros(1);
    if (limitesAzim(1)>limitesAzim(2))
        for i=0:intervalos
            aux=formatangle(elev,limitesAzim(1)-i*distinters);
            azims(i+1)=aux(2);
        end
    elseif (limitesAzim(1)<limitesAzim(2))
        for i=0:intervalos
            aux=formatangle(elev,limitesAzim(1)+i*distinters);
            azims(i+1)=aux(2);
        end
    else
        throw(MException("MATLAB:badargs","Los valores de los límites no son consistentes"));
    end
    
    numAzims = size(azims,2);
    
    %% Adecuación de algunos valores
    sizeaudio=size(audio);
    aux=mod(sizeaudio(1),numAzims)+1;
    audio=[audio(:,:); zeros(numAzims-aux+1,sizeaudio(2))];
    sizeaudio=size(audio);
    
    %% División del audio original
    audioDivs=zeros(numAzims, sizeaudio(1)/numAzims, 2);
    for segmento=1:numAzims
        audioDivs(segmento,:,:)=[audio((sizeaudio(1)/numAzims)*(segmento-1)+1:(sizeaudio(1)/numAzims)*(segmento),:)];
    end
    %% Interpolación HRIR para cada punto
    interpsH=zeros(numAzims, 512, 2);
    for segmento=1:numAzims
        interpsH(segmento,:,:)=interphrir(azims(segmento),elev);
    end
    
    %% Convolución de cada señal e impulso
    audioConvs=zeros(numAzims, sizeaudio(1)/numAzims+511, 2);
    for segmento=1:numAzims
        for canal=1:2
            audioConvs(segmento,:,canal)=conv(audioDivs(segmento,:,canal),interpsH(segmento,:,canal));
        end
    end
    
    %% Función de Disminución del Sonido
    t1 = linspace(0,2,511);
    fd = t1.';
    fd = exp(-2*fd);
    fd = [fd fd];
    fd = reshape(fd,1,size(fd,1),size(fd,2));
    
    %% Función de Incremento del Sonido
    t2 = linspace(0,2,511);
    fi = t2.';
    fi = exp(2*(fi-2));
    fi = [fi fi];
    fi = reshape(fi,1,size(fi,1),size(fi,2));
    
    %% Cross Fade de las Señales
    audioFades=zeros(numAzims, sizeaudio(1)/numAzims+511, 2);
    
    audioFades(1,:,:)=[audioConvs(1,1:sizeaudio(1)/numAzims,:) audioConvs(1,(sizeaudio(1)/numAzims+1):size(audioConvs,2),:).*fd];
    for segmento=2:numAzims-1
        audioFades(segmento,:,:)=[audioConvs(segmento,1:511,:).*fi audioConvs(segmento,512:1:sizeaudio(1)/numAzims,:) audioConvs(segmento,(sizeaudio(1)/numAzims+1):size(audioConvs,2),:).*fd];
    end
    audioFades(numAzims,:,:)=[audioConvs(numAzims,1:511,:).*fi audioConvs(numAzims,512:size(audioConvs,2),:)];
    
    %% Concatenación de las señales
    audioProcesado=[audioFades(1,1:sizeaudio(1)/numAzims,:) audioConvs(1,(sizeaudio(1)/numAzims+1):size(audioConvs,2),:)+audioConvs(2,1:511,:) audioConvs(2,512:sizeaudio(1)/numAzims,:)];
    for segmento=2:numAzims-1
        audioProcesado=[audioProcesado [audioConvs(segmento,(sizeaudio(1)/numAzims+1):size(audioConvs,2),:)+audioConvs(segmento+1,1:511,:) audioConvs(segmento+1,512:sizeaudio(1)/numAzims,:)]]; %#ok<AGROW> 
    end
    audioProcesado=[audioProcesado audioConvs(numAzims,(sizeaudio(1)/numAzims)+1:size(audioConvs,2),:)];
    audioProcesado=reshape(audioProcesado,size(audioProcesado,2),size(audioProcesado,3));
    
    %% Gráfico de la nueva señal
    % figure
    % subplot(3,2, [1 2])
    % plot(ta,audioProcesado(:,1),"Color","blue")
    % title("Canal Izquierdo")
    % subplot(3,2, [3 4])
    % plot(ta,audioProcesado(:,2),"Color",'red')
    % title("Canal Derecho")
    % subplot(3,2, [5 6])
    % plot(ta,audioProcesado)
    % title("Ambos Canales")

    %% Para crear el archivo
    if (banderaCrear==0)
        return
    elseif (banderaCrear==1)
        breakPoint=find(archivoAudio=='.',1,"last");
        newFileNAme=strcat(archivoAudio(1:(breakPoint-1)),'Var',archivoAudio(breakPoint:end));
        audiowrite(newFileNAme,audioProcesado,Fs);
    else
        throw(MException("MATLAB:badargs","0-No Crear Archivo o 1-Crear Archivo"));
    end

end