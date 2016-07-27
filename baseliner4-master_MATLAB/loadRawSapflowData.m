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

function [yearNum, par, vpd, sapflow, doy, tod] = loadRawSapflowData(filename)
    % Reads sapflow and other data from the specified file
    %TEMP!!! currently what data is in which column is hardcoded
    %TEMP!!!  doy and tod (day of year + time of day) might be dumped
    %TEMP!!! there's no error handling for missing files, bad data etc.
    raw = load(filename);

    [~, numCols] = size(raw);

    yearNum = raw(:, 2);
    dayOfYear = raw(:, 3);
    % Time is encoded as a decimal integer of value HMM.  So 4:15 would
    % yield the value 415
    encodedTime = raw(:, 4);
    hour = floor(encodedTime ./ 100);
    minute = mod(encodedTime, 100);

    % This might be a wee bit dodgy, I couldn't find documentation for
    % this.  I'm forcing datetime to use day-of-month data by holding the
    % month value to one.  Seems to work, including with leap years, but
    % the 'feature' might be deprecated in future.
    sampleTime = datetime(yearNum, 1, dayOfYear, hour, minute, 0);

    % Check that the time step is uniform.
    timeSteps = sampleTime(2:end) - sampleTime(1:end-1);       %TEMP!!! just use MATLAB's diff()

    interval = unique(timeSteps);
    if length(interval) ~= 1
        % There's more than one amount that neighbouring times change by...
        intervalList = sprintf('%d ', minutes(interval));
        throw(MException('sapflowData:fileError','Inconsistent sample intervals (%s minutes)', intervalList))
    end
    vpd = raw(:,5);
    par = raw(:,6);
    sapflow = raw(:,7:numCols);

    doy = dayOfYear;  %%TEMP!!!
    tod = encodedTime; %%TEMP!!!

    sapflow(sapflow >= 6999) = nan;  %TEMP!!!

end

