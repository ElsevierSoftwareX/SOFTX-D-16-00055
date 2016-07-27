% THIS SOFTWARE WAS DEVELOPED AT THE US FOREST SERVICE, SOUTHERN RESEARCH STATION (SRS), COWEETA HYDROLOGIC LABORATORY BY EMPLOYEES OF THE FEDERAL GOVERNMENT IN THE COURSE OF THEIR OFFICIAL DUTIES. 
% PURSUANT TO TITLE 17 SECTION 105 OF THE UNITED STATES CODE, THIS SOFTWARE IS NOT SUBJECT TO COPYRIGHT PROTECTION AND IS IN THE PUBLIC DOMAIN. 
% SRS COWEETA HYDROLOGIC LABORATORY ASSUMES NO RESPONSIBILITY WHATSOEVER FOR ITS USE BY OTHER PARTIES,  AND MAKES NO GUARANTEES, EXPRESSED OR IMPLIED, ABOUT ITS QUALITY, RELIABILITY, OR ANY OTHER CHARACTERISTIC.  
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
% IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
% 
% This file is part of Baseliner.
% 
% Baseliner is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.
% Baseliner is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
% See the GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License along with Baseliner. If not, see <http://www.gnu.org/licenses/>.


function [spbl lspbl zvbl lzvbl]=BL_auto(xSensor,DOY,xDOY,Timestep,PAR,PARthresh,VPD,VPDthresh,VPDtime);

    % Stability threshold for nighttime delta-T
    % percentage of difference in daily max-min for 1-week moving window
    tstab=0.01; % default 1%


    Vtt=VPDtime*(60/Timestep);
    zvbl=[];
    lzvbl=[];
    spbl=[];
    lspbl=[];
    for d=1:365
        % check for stable delta-T
        DI=find(xDOY==d & PAR<PARthresh & xSensor>0);
        if length(DI)>Vtt
            DI(1:Vtt-1)=[];
            if d<4
                drstart=1;drstop=7;
            elseif d>362
                drstart=358;drstop=365;
            else
                drstart=d-3;drstop=d+3;
            end
            dr=drstart:drstop;
            drval=nan*ones(7,2);
            for dri=1:7
                xx=xSensor(xDOY==dr(dri) & PAR<PARthresh);
                xx(isnan(xx))=[];
                if length(xx)>8*(60/Timestep)
                    drval(dri,1)=max(xx);
                end
                xx=xSensor(DOY==dr(dri) & PAR>PARthresh);
                xx(isnan(xx))=[];
                if length(xx)>8*(60/Timestep)
                    drval(dri,2)=min(xx);
                end
            end
            dtr=nanmean(drval(:,1))-nanmean(drval(:,2));

            spi=ones(length(DI),1); % local stable point indicator
            zvi=ones(length(DI),1); % local zero-vpd indicator
            for i=1:length(DI)
                ii=DI(i);
                xii=xSensor(ii-Vtt+1:ii);
                if std(xii)/dtr>tstab
                    spi(i)=0;
                end
                xii=VPD(ii-Vtt+1:ii);
                if mean(xii)>VPDthresh
                    zvi(i)=0;
                end
            end
            if nansum(spi)>0
                spbl=[spbl;DI(spi==1)]; % Stable Point Baseline
                spii=DI(spi==1);
                lspbl=[lspbl;spii(end)]; % Last Stable Point Baseline (final, stable point)
            end
            zvi=spi.*zvi;
            if nansum(zvi)>0
                zvbl=[zvbl;DI(zvi==1)]; % Zero-VPD Baseline (passes stable dT threshold)
                zvii=DI(zvi==1);
                lzvbl=[lzvbl;zvii(end)]; % Last Point Baseline (final, stable, zero-VPD point)
            end
        end
    end
end
