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

classdef MultiZoomer < handle
    % Manages concurrently graphic presentation of overview and zoomed data
    %
    %
    % On the one figure (window) we have two sets of charts*: one set shows an
    % overview of various data, the other set shows a zoomed in section of those
    % data.  The two sets contain the same number of charts and the X axes of
    % those charts are locked together.
    %
    % The display range of the overview charts remains fixed, zooming and
    % panning changes the zoom charts.  Rectangles superimposed on the overview
    % charts indicate where the zoom charts are focused on.
    %
    % Creation and positioning of the charts on the figure is not handled by
    % MultiZoomer.
    %
    % Panning and zooming is perfomed by:
    % - client code calling public MultiZoomer methods zoom(), pan() etc.
    % - operating the mouse wheel in any of the axes,
    % - dragging and clicking on the unzoomed axes
    %
    % MultiZoomer expects to set the figure's WindowScrollWheelFcn callback and
    % the unzoomed axes' ButtonDownFcn callback.
    %
    % *In MATLAB nomenclature the area that lines are plotted onto is called an
    % "axes", plural for "axis". I.e. "axes" is a singular. This convention
    % presents the problem of what to call multiple of these items. In order to
    % avoid the awful word "axeses", we will % refer to a MATLAB axes instance
    % as a "chart".
    %

    properties  %TEMP!!! sort out permissions
        figure     % handle to the single figure all charts reside on
        fullCharts % 1 x N cell array of handles to the unzoomed charts
        zoomCharts % 1 x N cell array of handles to the zoomed charts
        locRects  % 1 x N cell array of handles to polygons showing the extent of each zoom chart
        yLimits    % 1 x N cell array of 1 x 2 arrays containing the max extent of each chart
        numChartPairs % the value of N in the above
        xLimit     % 1 x 2 array containing X range of all charts
        xZoom      % 1 x 2 array with the current X range on all the zoom charts

    end

    methods (Access = public)


        function o = MultiZoomer(s)
            % Constructor
            %
            % Axes must already be set up.  s is a structure containing:
            % - figure: the handle to the figure containing the charts
            % - fullCharts: 1 x N cell array of handles to axes instances
            % - zoomCharts: another 1 x N cell array of handles to axes instances

            o.figure = s.figure;
            o.fullCharts = s.fullCharts;
            o.zoomCharts = s.zoomCharts;

            o.numChartPairs = length(o.fullCharts);
            for i = 1:o.numChartPairs
                fp = o.fullCharts{i};
                fp.ButtonDownFcn = @o.buttDownFullAxis;
                for j = 1:length(fp.Children)
                    fp.Children(j).HitTest = 'off';
                end
            end
        end


        function createZoomAreaIndicators(o)
            % The overview charts have rectangles showing the zoom chart areas.
            %
            % These are created after the data lines are created so that it
            % lays over those lines.  The rectangles are filled but transparent
            % so that the lines are still visible.
            %

            %TEMP!!! delete existing rects
            %TEMP!!! make private and call from setLimits()
            for i = 1:o.numChartPairs
                fp = o.fullCharts{i};
                hold(fp, 'on');
                o.locRects{i} = fill( ...
                    [0, 0, 0, 0], [0, 0, 0, 0], ...
                    'b', ...
                    'Parent', fp, ...
                    'FaceAlpha', 0.3, ...
                    'HitTest', 'Off', ...
                    'Visible', 'Off' ...
                    );
                hold(fp, 'off');
            end
        end


        function pan(o, dx)
            % Pan the zoomed section left or right
            %
            % dx is the distance to move: +1 shifts right by the full zoom width
            % -0.5 would pan left with a 50% overlap with the original veiw.
            % Stops at the ends defined in xLimit.
            %
            width = o.xZoom(2) - o.xZoom(1);
            if dx < 0
                % pan left
                xp1 = max(o.xLimit(1), o.xZoom(1) + dx * width);
                xp2 = xp1 + width;
            else
                % pan right
                xp2 = min(o.xZoom(2) + dx * width, o.xLimit(2));
                xp1 = xp2 - width;
            end
            o.setXZoom(xp1, xp2);
        end


        function zoom(o, k)
            % Zoom the X dimension in or out
            %
            % Keeping the centre of the zoomed section constant.  Respects the
            % xLimit points.
            %
            % k: ratio to zoom by: 2 doubles magnification, 0.5 zooms out by 2
            xp1 = max(o.xLimit(1), (o.xZoom(1) * (1-k) + o.xZoom(2) * k));
            xp2 = min(o.xLimit(2), (o.xZoom(2) * (1-k) + o.xZoom(1) * k));
            o.setXZoom(xp1, xp2);
        end


        function zoomToRange(o, chartI, xRange, yRange)
            % xRange and yRange are 1 x 2 arrays will min and max values
            % chartI is the index of the chart in the set.
            o.setXZoom(xRange(1), xRange(2));
            o.setYZoom(chartI, yRange);
        end


        function setXLimit(o, range)
            % Set the extent of the overview charts.
            %
            o.xLimit = range;
            for i = 1:o.numChartPairs
                fp = o.fullCharts{i};
                fp.XLim = range;
            end
            o.setXZoom(1, range(2)/10);
        end

        function setYLimits(o, ranges)
            % Set the extent of the overview charts.
            %
            %TEMP!!! also set max zoom ranges
            for i = 1:o.numChartPairs
                o.yLimits{i} = ranges{i};
                fp = o.fullCharts{i};
                fp.YLim = ranges{i};
            end
            o.restoreY();
        end


        function handleMouseInput(o, chartI)
            % Give control of mouse clicks in a zoom chart to MultiZoomer
            %
            % So that dragging, and clicking control zoom extent.
            % chartI is the index of the chart in the set.
            o.zoomCharts{chartI}.ButtonDownFcn = @o.buttDownFullAxis;
        end


        function disable(o)
            % Called when there's nothing to zoom on.  Stops the mouse
            % wheel from doing anything and hides the location rectangles.
            o.figure.WindowScrollWheelFcn = '';
            for i = 1:o.numChartPairs
                o.locRects{i}.Visible = 'Off';
            end
        end


        function enable(o)
            % Once data are loaded we call this to enable the mouse wheel
            % and display the location rectangles.
            o.figure.WindowScrollWheelFcn = @o.wheelCallback;
            for i = 1:o.numChartPairs
                o.locRects{i}.Visible = 'On';
            end
        end

    end

    methods (Access = private)


        function zoomToBox(o, chart, p1, p2)
            if p1 == p2  % a click
                xc = p1(1,1);
                width = o.xZoom(2) - o.xZoom(1);
                xp1 = max(o.xLimit(1), xc - width / 2);
                xp2 = min(xp1 + width, o.xLimit(2));
                xp1 = xp2 - width;
            else
                xp1 = p1(1,1);
                xp2 = p2(1,1);
                yp1 = p1(1,2);
                yp2 = p2(1,2);
                for i = 1:o.numChartPairs
                    if o.fullCharts{i} == chart || o.zoomCharts{i} == chart
                        o.setYZoom(i, sort([yp1, yp2]));
                    end
                end
            end
            o.setXZoom(xp1, xp2);
        end


        function restoreY(o)
            for i = 1:o.numChartPairs
                yp1 = o.yLimits{i}(1);
                yp2 = o.yLimits{i}(2);
                o.zoomCharts{i}.YLim = [yp1, yp2];
                o.locRects{i}.YData = [yp1, yp1, yp2, yp2];
            end
        end


        function buttDownFullAxis(o, chart, ~)
            p1 = chart.CurrentPoint();
            rbbox();
            p2 = chart.CurrentPoint();

            o.zoomToBox(chart, p1, p2);
        end


        function a = findAxesWhichMouseIsOn(o)

            function a = isMouseOver(p, zone)
                a = ...
                    (p(1) >= zone(1)) && (p(1) <= zone(1) + zone(3)) && ...
                    (p(2) >= zone(2)) && (p(2) <= zone(2) + zone(4));
            end

            p = o.figure.CurrentPoint();
            for i = 1:length(o.fullCharts)
                zone = o.fullCharts{i}.Position();
                if isMouseOver(p, zone)
                    a = {'f', i, o.fullCharts{i}};
                    return
                end
            end
            for i = 1:length(o.zoomCharts)
                zone = o.zoomCharts{i}.Position();
                if isMouseOver(p, zone)
                    a = {'z', i, o.zoomCharts{i}};
                    return
                end
            end

            % not over any chart
            a = {0};
            return;

        end


        function wheelCallback(o,~,evt)
            mouseLoc = o.findAxesWhichMouseIsOn();
            if mouseLoc{1} == 0
                return
            end
            axesI = mouseLoc{2};
            chart = mouseLoc{3};
            wheelDir = evt.VerticalScrollCount;
            if (wheelDir > 0)
                k = -0.2;
            else
                k = 0.2;
            end
            if mouseLoc{1} == 'z'
                p = chart.CurrentPoint();
                xp = p(1,1);
                yp = p(1,2);
                xSpan = o.zoomCharts{axesI}.XLim;
                ySpan = o.zoomCharts{axesI}.YLim;
                xp1 = max(o.xLimit(1), (xSpan(1) * (1-k) + xp * k));
                xp2 = min(o.xLimit(2), (xSpan(2) * (1-k) + xp * k));
                yLim = o.yLimits{axesI};
                yp1 = max(yLim(1),(ySpan(1) * (1-k) + yp * k));
                yp2 = min(yLim(2),(ySpan(2) * (1-k) + yp * k));
                o.zoomCharts{axesI}.YLim = [yp1, yp2];
                o.locRects{axesI}.YData = [yp1, yp1, yp2, yp2];
            elseif mouseLoc{1} == 'f'
                k = k / 2;
                xp1 = max(o.xLimit(1), (o.xZoom(1) * (1-k) + o.xZoom(2) * k));
                xp2 = min(o.xLimit(2), (o.xZoom(2) * (1-k) + o.xZoom(1) * k));
            end

            o.setXZoom(xp1, xp2);
        end


        function setYZoom(o, i, range)
            o.zoomCharts{i}.YLim = range;
            o.locRects{i}.YData = range([1, 1, 2, 2]);
        end


        function setXZoom(o, xp1, xp2)
            o.xZoom = sort([xp1, xp2]);
            for i = 1:o.numChartPairs
                o.zoomCharts{i}.XLim = o.xZoom;
                o.locRects{i}.XData = [xp1, xp2, xp2, xp1];
            end
        end


    end
end
