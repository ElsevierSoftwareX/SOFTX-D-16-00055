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


function [bl_night]=BL_nightly(xSensor,DOY,TOD)
    % establishes initial baseline based on maximum dT value each
    % night (defined by time before 7:00 AM)
    bl_night=[];
    for d=min(DOY):max(DOY)
        DI=find(DOY==d & TOD<700 & xSensor'>0);
        if length(DI)>0
            [mDI,iDI]=max(xSensor(DI));
            if length(iDI)>=1
                bl_night=[bl_night;DI(iDI(1))];
            end
        end
    end
    bl_night=[1;bl_night;length(xSensor)];
    bl_night=unique(bl_night)';
end

