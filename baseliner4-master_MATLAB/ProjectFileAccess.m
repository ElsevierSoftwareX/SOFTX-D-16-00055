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

classdef ProjectFileAccess < handle
    % Used to constuct the XML based project file for the sapflow tool.
    % Does this by building up a DOM document intermediate and calling
    % MATLAB's xmlwrite().
    %
    % The code used to read these files is located in loadSapflowConfig().

    properties (Access = private)
        docNode
    end
    properties (GetAccess = public, SetAccess = private)
        docRootNode
    end

    methods (Access = public)

        function o = ProjectFileAccess()
            % Constructor.  Creates the intermediate document.
            o.docNode = com.mathworks.xml.XMLUtils.createDocument('SapflowProject');
            o.docRootNode = o.docNode.getDocumentElement();

            % This protocol number might be used by future versions of the
            % code to provide backwards compatability.
            o.docRootNode.setAttribute('protocolVersion', num2str(1));
        end


        function save(o, filename)
            % Having built up the DOM we can save it to an XML file.
            xmlwrite(filename, o.docNode);
        end


        function writeConfig(o, s)
            % Builds the <ProjectConfig> bit of the DOM.
            element = o.docNode.createElement('ProjectConfig');

            % This is to allow future versions of the code to identify
            % older versions of the project file and either deal with it
            % or reject it.

            o.addTextElement(element, 'ProjectName', s.projectName);
            o.addTextElement(element, 'ProjectDesc', s.projectDesc);
            o.addTextElement(element, 'SourceFilename', s.sourceFilename);
            o.addIntegerElement(element, 'Timestep', s.Timestep);
            o.addIntegerElement(element, 'NumberSensors', s.numSensors);
            o.addFloatElement(element, 'MinRawValue', s.minRawValue);
            o.addFloatElement(element, 'MaxRawValue', s.maxRawValue);
            o.addFloatElement(element, 'MaxRawStep', s.maxRawStep);
            o.addIntegerElement(element, 'MinRunLength', s.minRunLength);
            o.addFloatElement(element, 'ParThresh', s.parThresh);
            o.addFloatElement(element, 'VpdThresh', s.vpdThresh);
            o.addFloatElement(element, 'VpdTime', s.vpdTime);

            o.docRootNode.appendChild(element);
        end


        function writeSensor(o, num, s)
            % Builds the sensor data state for a sensor.
            % Structure will be:
            % <Sensor number="5">
            %    <spbl>1 2 3 ...</spbl>
            %    <zvbl>1 2 3 ...</zvbl>
            %    <lzvbl>1 2 3 ...</lzvbl>
            %    <bla>1 2 3 ...</bla>
            %    <Sapflow>
            %         <Cut start="100" end="200"/>
            %         ...
            %         <New start="300" end="400">1.1 2.3 3.6 ...</New>
            %         ...
            %    </Sapflow>
            % </Sensor>
            sensor = o.docNode.createElement('Sensor');
            sensor.setAttribute('number', num2str(num));

            o.addIntegerElement(sensor, 'spbl', s.spbl);
            o.addIntegerElement(sensor, 'zvbl', s.zvbl);
            o.addIntegerElement(sensor, 'lzvbl', s.lzvbl);
            o.addIntegerElement(sensor, 'bla', s.bla);

            sapflow = o.docNode.createElement('Sapflow');

            for seg = s.sapflow.cut
                segv = seg{1};
                sel = o.docNode.createElement('Cut');
                sel.setAttribute('start', num2str(segv.start));
                sel.setAttribute('end', num2str(segv.end));
                sapflow.appendChild(sel);
            end
            for seg = s.sapflow.new
                segv = seg{1};
                sel = o.docNode.createElement('New');
                sel.setAttribute('start', num2str(segv.start));
                sel.setAttribute('end', num2str(segv.end));
                sel.appendChild(o.textNodeOfFloats(segv.data));
                sapflow.appendChild(sel);
            end
            sensor.appendChild(sapflow);
            o.docRootNode.appendChild(sensor);
        end

    end

    methods (Access = private)

        function textNode = textNodeOfFloats(o, values)
            text = strtrim(sprintf('%f ', values));
            textNode = o.docNode.createTextNode(text);
        end

        function addTextElement(o, parent, nodeName, nodeValue)
            % Create an XML element with a string value.
            % E.g. nodeName == 'name' and nodeValue = 'joe'
            % gives: <name>joe</name>
            element = o.docNode.createElement(nodeName);
            textNode = o.docNode.createTextNode(nodeValue);
            element.appendChild(textNode);
            parent.appendChild(element);
        end


        function addIntegerElement(o, parent, nodeName, nodeValue)
            % Create an XML element whose value represents an integer
            % or vector of ints.
            % E.g. nodeName == 'spbl' and nodeValue = [213, 214, 215, 216]
            % gives: <spbl>213 214 215 216</spbl>
            o.addTextElement(parent, nodeName, strtrim(sprintf('%d ', nodeValue)));
        end


        function addFloatElement(o, parent, nodeName, nodeValue)
            % Create an XML element whose value represents a float
            % or vector of floats.
            % E.g. nodeName == 'spbl' and nodeValue = [213, 214, 215, 216]
            % gives: <spbl>213 214 215 216</spbl>
            o.addTextElement(parent, nodeName, strtrim(sprintf('%f ', nodeValue)));
        end


    end
end
